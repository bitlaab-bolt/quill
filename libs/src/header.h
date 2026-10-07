// Needed so sqlite3ext.h doesn't redefine sqlite3_* as sqlite3_api->* macros,
// which would break translation and linking against the amalgamation.
#define SQLITE_CORE 1

#include <sqlite3.h>
#include <sqlite3ext.h>