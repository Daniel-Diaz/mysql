{-# LANGUAGE EmptyDataDecls, ForeignFunctionInterface #-}

module Database.MySQL.C
    (
    -- * Connection management
      mysql_init
    , mysql_real_connect
    , mysql_close
    , mysql_ping
    , mysql_autocommit
    , mysql_change_user
    , mysql_select_db
    , mysql_set_character_set
    -- ** Connection information
    , mysql_thread_id
    , mysql_get_server_info
    , mysql_get_host_info
    , mysql_get_proto_info
    , mysql_character_set_name
    , mysql_get_ssl_cipher
    , mysql_stat
    -- * Querying
    , mysql_real_query
    -- ** Escaping
    , mysql_real_escape_string
    -- ** Results
    , mysql_field_count
    , mysql_affected_rows
    , mysql_store_result
    , mysql_use_result
    , mysql_fetch_lengths
    , mysql_fetch_lengths_nonblock
    , mysql_fetch_row
    , mysql_fetch_row_nonblock
    -- * Working with results
    , mysql_free_result
    , mysql_fetch_fields
    , mysql_fetch_fields_nonblock
    -- ** Multiple results
    , mysql_next_result
    -- * General information
    , mysql_get_client_info
    , mysql_get_client_version
    -- * Error handling
    , mysql_errno
    , mysql_error
    -- * Support functions
    , withRTSSignalsBlocked
    ) where

#include "mysql.h"
#include <signal.h>

import Database.MySQL.Types
import Control.Concurrent (rtsSupportsBoundThreads, runInBoundThread)
import Control.Exception (finally)
import Foreign.C.String (CString)
import Foreign.C.Types
import Foreign.ForeignPtr (ForeignPtr, mallocForeignPtr, withForeignPtr)
import Foreign.Ptr (Ptr, nullPtr)
import System.IO.Unsafe (unsafePerformIO)
import Foreign.Storable

-- | Execute an 'IO' action with signals used by GHC's runtime signals
-- blocked.  The @mysqlclient@ C library does not correctly restart
-- system calls if they are interrupted by signals, so many MySQL API
-- calls can unexpectedly fail when called from a Haskell application.
-- This is most likely to occur if you are linking against GHC's
-- threaded runtime (using the @-threaded@ option).
--
-- This function blocks @SIGALRM@ and @SIGVTALRM@, runs your action,
-- then unblocks those signals.  If you have a series of HDBC calls
-- that may block for a period of time, it may be wise to wrap them in
-- this action.  Blocking and unblocking signals is cheap, but not
-- free.
--
-- Here is an example of an exception that could be avoided by
-- temporarily blocking GHC's runtime signals:
--
-- >  SqlError {
-- >    seState = "", 
-- >    seNativeError = 2003, 
-- >    seErrorMsg = "Can't connect to MySQL server on 'localhost' (4)"
-- >  }
withRTSSignalsBlocked :: IO a -> IO a
withRTSSignalsBlocked act
    | not rtsSupportsBoundThreads = act
    | otherwise = runInBoundThread . withForeignPtr rtsSignals $ \set -> do
  pthread_sigmask (#const SIG_BLOCK) set nullPtr
  act `finally` pthread_sigmask (#const SIG_UNBLOCK) set nullPtr

rtsSignals :: ForeignPtr SigSet
rtsSignals = unsafePerformIO $ do
               fp <- mallocForeignPtr
               withForeignPtr fp $ \set -> do
                 sigemptyset set
                 sigaddset set (#const SIGALRM)
                 sigaddset set (#const SIGVTALRM)
               return fp
{-# NOINLINE rtsSignals #-}

data SigSet

instance Storable SigSet where
    sizeOf    _ = #{size sigset_t}
    alignment _ = alignment (undefined :: Ptr CInt)

foreign import ccall unsafe "signal.h sigaddset" sigaddset
    :: Ptr SigSet -> CInt -> IO ()

foreign import ccall unsafe "signal.h sigemptyset" sigemptyset
    :: Ptr SigSet -> IO ()

foreign import ccall unsafe "signal.h pthread_sigmask" pthread_sigmask
    :: CInt -> Ptr SigSet -> Ptr SigSet -> IO ()

foreign import ccall safe mysql_init
    :: Ptr MYSQL                -- ^ should usually be 'nullPtr'
    -> IO (Ptr MYSQL)

foreign import ccall unsafe mysql_real_connect
    :: Ptr MYSQL -- ^ context (from 'mysql_init')
    -> CString   -- ^ hostname
    -> CString   -- ^ username
    -> CString   -- ^ password
    -> CString   -- ^ database
    -> CInt      -- ^ port
    -> CString   -- ^ unix socket
    -> IO (Ptr MYSQL)

foreign import ccall unsafe mysql_close
    :: Ptr MYSQL -> IO ()

foreign import ccall unsafe mysql_ping
    :: Ptr MYSQL -> IO CInt

foreign import ccall safe mysql_thread_id
    :: Ptr MYSQL -> IO CULong

foreign import ccall unsafe mysql_autocommit
    :: Ptr MYSQL -> MyBool -> IO MyBool

foreign import ccall unsafe mysql_change_user
    :: Ptr MYSQL
    -> CString                  -- ^ user
    -> CString                  -- ^ password
    -> CString                  -- ^ database
    -> IO MyBool

foreign import ccall unsafe mysql_select_db
    :: Ptr MYSQL
    -> CString
    -> IO CInt

foreign import ccall safe mysql_get_server_info
    :: Ptr MYSQL -> IO CString

foreign import ccall safe mysql_get_host_info
    :: Ptr MYSQL -> IO CString

foreign import ccall safe mysql_get_proto_info
    :: Ptr MYSQL -> IO CUInt

foreign import ccall safe mysql_character_set_name
    :: Ptr MYSQL -> IO CString

foreign import ccall safe mysql_set_character_set
    :: Ptr MYSQL -> CString -> IO CInt

foreign import ccall safe mysql_get_ssl_cipher
    :: Ptr MYSQL -> IO CString

foreign import ccall unsafe mysql_stat
    :: Ptr MYSQL -> IO CString

foreign import ccall unsafe mysql_real_query
    :: Ptr MYSQL -> CString -> CULong -> IO CInt

foreign import ccall safe mysql_field_count
    :: Ptr MYSQL -> IO CUInt

foreign import ccall safe mysql_affected_rows
    :: Ptr MYSQL -> IO CULLong

foreign import ccall unsafe mysql_store_result
    :: Ptr MYSQL -> IO (Ptr MYSQL_RES)

foreign import ccall unsafe mysql_use_result
    :: Ptr MYSQL -> IO (Ptr MYSQL_RES)

foreign import ccall unsafe mysql_free_result
    :: Ptr MYSQL_RES -> IO ()

foreign import ccall unsafe mysql_fetch_fields
    :: Ptr MYSQL_RES -> IO (Ptr Field)

foreign import ccall safe "mysql.h mysql_fetch_fields" mysql_fetch_fields_nonblock
    :: Ptr MYSQL_RES -> IO (Ptr Field)

foreign import ccall unsafe mysql_next_result
    :: Ptr MYSQL -> IO CInt

foreign import ccall unsafe mysql_fetch_row
    :: Ptr MYSQL_RES -> IO MYSQL_ROW

foreign import ccall safe "mysql.h mysql_fetch_row" mysql_fetch_row_nonblock
    :: Ptr MYSQL_RES -> IO MYSQL_ROW

foreign import ccall unsafe mysql_fetch_lengths
    :: Ptr MYSQL_RES -> IO (Ptr CULong)

foreign import ccall safe "mysql.h mysql_fetch_lengths" mysql_fetch_lengths_nonblock
    :: Ptr MYSQL_RES -> IO (Ptr CULong)

foreign import ccall safe mysql_real_escape_string
    :: Ptr MYSQL -> CString -> CString -> CULong -> IO CULong

foreign import ccall safe mysql_get_client_info :: CString

foreign import ccall safe mysql_get_client_version :: CULong

foreign import ccall safe mysql_errno
    :: Ptr MYSQL -> IO CInt

foreign import ccall safe mysql_error
    :: Ptr MYSQL -> IO CString
