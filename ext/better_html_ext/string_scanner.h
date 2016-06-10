#pragma once

enum string_scanner_context {
  SS_TEXT = 0,
  SS_MARKER,
};

enum ss_token_type {
  SS_TOKEN_NONE = 0,
  SS_TOKEN_TEXT,
  SS_TOKEN_PERCENT,
  SS_TOKEN_MARKER_START,
  SS_TOKEN_MARKER_END,
  SS_TOKEN_IDENTIFIER,
  SS_TOKEN_MALFORMED,
};

struct scan_t {
  char *string;
  unsigned long int cursor;
  unsigned long int length;
};

struct string_scanner_t {
  enum string_scanner_context context;

  void *callback_data;
  void (*f_callback)(struct string_scanner_t *ss, enum ss_token_type type, unsigned long int length, void *data);

  struct scan_t scan;
};

void Init_better_html_string_scanner(VALUE mBetterHtml);
void string_scanner_init(struct string_scanner_t *tk);
VALUE string_scanner_token_type_to_symbol(enum ss_token_type type);

extern const rb_data_type_t string_scanner_data_type;
#define StringScanner_Get_Struct(obj, sval) TypedData_Get_Struct(obj, struct string_scanner_t, &string_scanner_data_type, sval)
