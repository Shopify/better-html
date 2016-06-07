#include <ruby.h>
#include "string_scanner.h"

static VALUE mBetterHtml = Qnil;

void Init_better_html_ext()
{
  mBetterHtml = rb_define_module("BetterHtml");
  Init_better_html_string_scanner(mBetterHtml);
}
