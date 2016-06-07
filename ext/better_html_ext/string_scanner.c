#include <ruby.h>
#include "string_scanner.h"

static VALUE cStringScanner = Qnil;

VALUE text_symbol,
  percent_symbol,
  marker_start_symbol,
  marker_end_symbol,
  identifier_symbol,
  malformed_symbol
;

static void string_scanner_mark(void *ptr)
{}

static void string_scanner_free(void *ptr)
{
  struct string_scanner_t *ss = ptr;
  xfree(ss);
}

static size_t string_scanner_memsize(const void *ptr)
{
  return ptr ? sizeof(struct string_scanner_t) : 0;
}

const rb_data_type_t string_scanner_data_type = {
  "better_html_string_scanner",
  { string_scanner_mark, string_scanner_free, string_scanner_memsize, },
#if defined(RUBY_TYPED_FREE_IMMEDIATELY)
  NULL, NULL, RUBY_TYPED_FREE_IMMEDIATELY
#endif
};

static VALUE string_scanner_allocate(VALUE klass)
{
  VALUE obj;
  struct string_scanner_t *ss;

  obj = TypedData_Make_Struct(klass, struct string_scanner_t, &string_scanner_data_type, ss);

  return obj;
}

void string_scanner_init(struct string_scanner_t *ss)
{
  ss->context = SS_TEXT;

  ss->callback_data = NULL;
  ss->f_callback = NULL;

  return;
}

static void string_scanner_yield_tag(struct string_scanner_t *ss, VALUE sym, uint32_t length, void *data)
{
  rb_yield_values(3, sym, INT2NUM(ss->scan.cursor), INT2NUM(ss->scan.cursor + length));
}

static void string_scanner_callback(struct string_scanner_t *ss, VALUE sym, uint32_t length)
{
  if(ss->f_callback)
    ss->f_callback(ss, sym, length, ss->callback_data);
  ss->scan.cursor += length;
}

static VALUE string_scanner_initialize_method(VALUE self)
{
  struct string_scanner_t *ss;

  StringScanner_Get_Struct(self, ss);
  string_scanner_init(ss);
  ss->f_callback = string_scanner_yield_tag;

  return Qnil;
}

static inline int eos(struct scan_t *scan)
{
  return scan->cursor >= scan->length;
}

static inline int length_remaining(struct scan_t *scan)
{
  return scan->length - scan->cursor;
}

static int is_text(struct scan_t *scan, uint32_t *length)
{
  uint32_t i;

  *length = 0;
  for(i = scan->cursor;i < scan->length; i++, (*length)++) {
    if(scan->string[i] == '%')
      break;
  }
  return *length != 0;
}

static inline int is_percent(struct scan_t *scan)
{
  return (length_remaining(scan) >= 2) &&
    scan->string[scan->cursor] == '%' &&
    scan->string[scan->cursor+1] == '%';
}

static inline int is_marker_start(struct scan_t *scan)
{
  return (length_remaining(scan) >= 2) &&
    scan->string[scan->cursor] == '%' &&
    scan->string[scan->cursor+1] == '{';
}

static inline int is_marker_end(struct scan_t *scan)
{
  return (length_remaining(scan) >= 1) &&
    scan->string[scan->cursor] == '}';
}

static int is_identifier(struct scan_t *scan, const char **identifier, uint32_t *identifier_length)
{
  uint32_t i;

  *identifier_length = 0;
  *identifier = &scan->string[scan->cursor];
  for(i = scan->cursor;i < scan->length; i++, (*identifier_length)++) {
    if(scan->string[i] == '}')
      break;
  }

  return *identifier_length != 0;
}

static int scan_text(struct string_scanner_t *ss)
{
  uint32_t length = 0;

  if(is_percent(&ss->scan)) {
    string_scanner_callback(ss, percent_symbol, 2);
    return 1;
  }
  else if(is_marker_start(&ss->scan)) {
    string_scanner_callback(ss, marker_start_symbol, 2);
    ss->context = SS_MARKER;
    return 1;
  }
  else if(is_text(&ss->scan, &length)) {
    string_scanner_callback(ss, text_symbol, length);
    return 1;
  }
  return 0;
}

static int scan_marker(struct string_scanner_t *ss)
{
  uint32_t length = 0;
  char *identifier = NULL;
  uint32_t identifier_length = 0;

  if(is_marker_end(&ss->scan)) {
    string_scanner_callback(ss, marker_end_symbol, 1);
    ss->context = SS_TEXT;
    return 1;
  }
  else if(is_identifier(&ss->scan, &identifier, &identifier_length)) {
    string_scanner_callback(ss, identifier_symbol, identifier_length);
    return 1;
  }
  return 0;
}

static int scan_once(struct string_scanner_t *ss)
{
  switch(ss->context) {
  case SS_TEXT:
    return scan_text(ss);
  case SS_MARKER:
    return scan_marker(ss);
  }
  return 0;
}

void scan_all(struct string_scanner_t *ss)
{
  while(!eos(&ss->scan) && scan_once(ss)) {}
  if(!eos(&ss->scan)) {
    string_scanner_callback(ss, malformed_symbol, length_remaining(&ss->scan));
  }
  return;
}

static VALUE string_scanner_scan_method(VALUE self, VALUE source)
{
  struct string_scanner_t *ss = NULL;

  Check_Type(source, T_STRING);
  StringScanner_Get_Struct(self, ss);

  ss->scan.string = RSTRING_PTR(source);
  ss->scan.cursor = 0;
  ss->scan.length = RSTRING_LEN(source);

  scan_all(ss);

  return Qnil;
}

void Init_better_html_string_scanner(VALUE mBetterHtml)
{
  cStringScanner = rb_define_class_under(mBetterHtml, "StringScanner", rb_cObject);
  rb_define_alloc_func(cStringScanner, string_scanner_allocate);
  rb_define_method(cStringScanner, "initialize", string_scanner_initialize_method, 0);
  rb_define_method(cStringScanner, "scan", string_scanner_scan_method, 1);

  text_symbol = ID2SYM(rb_intern("text"));
  percent_symbol = ID2SYM(rb_intern("percent"));
  marker_start_symbol = ID2SYM(rb_intern("marker_start"));
  marker_end_symbol = ID2SYM(rb_intern("marker_end"));
  identifier_symbol = ID2SYM(rb_intern("identifier"));
}
