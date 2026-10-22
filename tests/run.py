"""Run mocked-client integration checks with Lua or an installed liblua."""
from pathlib import Path
import ctypes
import ctypes.util
import os
import shutil
import subprocess
import sys

os.chdir(Path(__file__).resolve().parent.parent)
executable = next((shutil.which(n) for n in ("lua5.1", "lua", "lua5.4") if shutil.which(n)), None)
if executable:
    raise SystemExit(subprocess.call([executable, "tests/smoke.lua"]))
library = next((ctypes.util.find_library(n) for n in ("lua5.4", "lua5.3") if ctypes.util.find_library(n)), None)
if not library:
    sys.exit("Install Lua 5.1+ or liblua5.3/liblua5.4 to run the mocked-client checks.")
lua = ctypes.CDLL(library)
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)
result = lua.luaL_loadfilex(state, b"tests/smoke.lua", None)
if not result:
    result = lua.lua_pcallk(state, 0, 0, 0, 0, None)
if result:
    print(lua.lua_tolstring(state, -1, None).decode("utf-8", "replace"), file=sys.stderr)
lua.lua_close(state)
raise SystemExit(1 if result else 0)
