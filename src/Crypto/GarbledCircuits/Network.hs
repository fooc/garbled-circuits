module Crypto.GarbledCircuits.Network
  (
    simpleConn
  , send
  , recv
  , connectTo
  , listenAt
  )
where

import Crypto.GarbledCircuits.Types
import Crypto.GarbledCircuits.Util

import           Control.Monad
import qualified Data.ByteString.Char8 as BS
import           Data.Serialize (decode, encode, Serialize)
import           Network.Socket hiding (send, recv)
import           Network.BSD
import           System.IO

--------------------------------------------------------------------------------
-- network

simpleConn :: Handle -> Connection
simpleConn h = Connection { conn_send = BS.hPut h, conn_recv = BS.hGet h }

send :: Serialize a => Connection -> a -> IO ()
send c x = do
    let encoding = encode x; n = BS.length encoding
    traceM ("[send] sending " ++ show n ++ " bytes")
    conn_send c (encode n)
    conn_send c encoding

recv :: Serialize a => Connection -> IO a
recv c = do
    num <- conn_recv c 8
    let n = either (err "recieve") id (decode num)
    str <- conn_recv c n
    traceM ("[recv] recieved " ++ show n ++ " bytes")
    either (err "recv") return (decode str)

connectTo :: HostName -> Port -> (Handle -> IO a) -> IO a
connectTo host port_ f = withSocketsDo $ do
    let port = toEnum port_
    sock <- socket AF_INET Stream 0
    addrs <- liftM hostAddresses $ getHostByName host
    when (null addrs) $ err "connectTo" ("no such host: " ++ host)
    connect sock $ SockAddrInet port (head addrs)
    perform sock f

listenAt :: Port -> (Handle -> IO a) -> IO a
listenAt port_ f = withSocketsDo $ do
    let port = toEnum port_
    lsock <- socket AF_INET Stream 0
    bindSocket lsock (SockAddrInet port iNADDR_ANY)
    listen lsock sOMAXCONN
    (sock,SockAddrInet _ _) <- accept lsock
    perform sock f

perform :: Socket -> (Handle -> IO a) -> IO a
perform sock f = withSocketsDo $ do
    handle <- socketToHandle sock ReadWriteMode
    result <- f handle
    hClose handle
    return result
