#pragma once

#define DBG_PRINT(msg, arg...) printf("%s:%u: " msg "\n", __FUNCTION__, __LINE__, arg);
