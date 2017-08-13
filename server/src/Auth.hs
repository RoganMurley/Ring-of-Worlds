module Auth where

import Control.Monad.Trans.Class (lift)
import Crypto.BCrypt (validatePassword, hashPasswordUsingPolicy, slowerBcryptHashingPolicy)
import Data.String.Conversions (cs)
import Data.Time.Clock (secondsToDiffTime)
import Network.HTTP.Types.Status
import Network.Wai (Application)
import Web.Cookie (setCookieMaxAge)
import Web.Scotty
import Web.Scotty.Cookie (deleteCookie, getCookie, makeSimpleCookie, setCookie)

import qualified Data.GUID as GUID
import qualified Database.Redis as R

import Data.Text (Text)
import qualified Data.Text.IO as T
import qualified Data.Text.Encoding as T


app :: R.Connection -> R.Connection -> IO Application
app userConn tokenConn =
  scottyApp $ do
    post "/login"    $ login userConn tokenConn
    post "/logout"   $ logout tokenConn
    post "/register" $ register userConn


login :: R.Connection -> R.Connection -> ActionM ()
login userConn tokenConn = do
  username <- param "username"
  password <- param "password"
  gotten <- lift . (R.runRedis userConn) $ R.get username
  case gotten of
    Right pass ->
      case pass of
        Just hashedPassword ->
          case validatePassword hashedPassword password of
            True -> do
              token <- lift GUID.genText
              let cookie = (makeSimpleCookie "login" token) { setCookieMaxAge = Just (secondsToDiffTime loginTimeout) }
              setCookie cookie
              _ <- lift . (R.runRedis tokenConn) $ do
                _ <- R.set (cs token) username
                R.expire (cs token) loginTimeout
              status ok200
            False -> do
              status unauthorized401
        Nothing ->
          status unauthorized401
    Left _ -> do
      lift . T.putStrLn $ "Database connection error"
      status internalServerError500


logout :: R.Connection -> ActionM ()
logout tokenConn = do
  token <- getCookie "login"
  case token of
    Just t -> do
      _ <- lift . (R.runRedis tokenConn) $ R.del [T.encodeUtf8 t]
      deleteCookie "login"
      status noContent204
    Nothing ->
      status noContent204


register :: R.Connection -> ActionM ()
register userConn = do
  username <- param "username"
  password <- param "password"
  p <- lift $ hashPasswordUsingPolicy slowerBcryptHashingPolicy password
  case p of
    Just hashedPassword -> do
      _ <- lift . (R.runRedis userConn) $ R.set username hashedPassword
      status created201
    Nothing ->
      status internalServerError500


checkAuth :: R.Connection -> Token -> IO (Maybe Username)
checkAuth tokenConn token = do
  gotten <- (R.runRedis tokenConn) . R.get $ T.encodeUtf8 token
  case gotten of
    Right username ->
      return (T.decodeUtf8 <$> username)
    Left _ -> do
      T.putStrLn $ "Database connection error"
      return Nothing


type Token    = Text
type Username = Text
type Seconds  = Integer


data Database =
    UserDatabase
  | TokenDatabase


connectInfo :: Database -> R.ConnectInfo
connectInfo database =
  R.defaultConnectInfo
    { R.connectHost     = "redis"
    , R.connectDatabase = asId database
    }
  where
    asId :: Database -> Integer
    asId UserDatabase  = 0
    asId TokenDatabase = 1


loginTimeout :: Seconds
loginTimeout = 60
