{-# LANGUAGE FlexibleContexts #-}

import qualified Data.ByteString as B
import qualified Data.Text       as T
import           LibFtdi         (DeviceHandle, ftdiDeInit, ftdiInit,
                                  ftdiUSBClose, ftdiUSBOpen, ftdiUSBReset,
                                  ftdiWriteData, ftdiReadData, withFtdi)
import           Protolude

-- FOR /home/jason/Develop/haskell/FPGAIPFilter_1/DE0_Nano_JTAG_RW.qar

-- Derived from https://github.com/GeezerGeek/open_sld/blob/master/sld_interface.py,
-- And: http://sourceforge.net/p/ixo-jtag/code/HEAD/tree/usb_jtag/

-- Load the initialTest.sof from open_sld on the board and run... ;-)
-- The initial test wires the DS0-Nano LED bank up to the SLD

jtagOFF, jtagTCK, jtagTMS, jtagTDI, jtagLED, jtagRD, jtagSHM, jtagnCE, jtagnCS :: Word8
jtagOFF = 0x00
jtagTCK = 0x01
jtagTMS = 0x02
jtagnCE = 0x04
jtagnCS = 0x08
jtagTDI = 0x10
jtagLED = 0x20
jtagRD  = 0x40
jtagSHM = 0x80

irAddrVir, irAddrVdr :: Word16
irAddrVir = 0x0E
irAddrVdr = 0x0C

virAddrBase :: Word8
virAddrBase = 0x10

irAddrLen, virAddrLen :: Int
irAddrLen  = 10
virAddrLen = 5

jtagM0D0R, jtagM0D1R, jtagM1D0R, jtagM1D1R :: [Word8]
-- Bit-mode - Two byte codes
jtagM0D0R = [ jtagLED                         .|. jtagRD,
              jtagLED                         .|. jtagTCK
            ]
jtagM0D1R = [ jtagLED .|. jtagTDI             .|. jtagRD,
              jtagLED             .|. jtagTDI .|. jtagTCK
            ]
jtagM1D0R = [ jtagLED .|. jtagTMS             .|. jtagRD,
              jtagLED .|. jtagTMS .|. jtagTCK
            ]
jtagM1D1R = [ jtagLED .|. jtagTMS .|. jtagTDI .|. jtagRD,
              jtagLED .|. jtagTMS .|. jtagTDI .|. jtagTCK
            ]

jtagM0D0, jtagM0D1, jtagM1D0, jtagM1D1 :: [Word8]
jtagM0D0 = [ jtagLED                         ,
             jtagLED                         .|. jtagTCK
           ]
jtagM0D1 = [ jtagLED .|. jtagTDI             ,
             jtagLED             .|. jtagTDI .|. jtagTCK
           ]
jtagM1D0 = [ jtagLED .|. jtagTMS             ,
             jtagLED .|. jtagTMS             .|. jtagTCK
           ]
jtagM1D1 = [ jtagLED .|. jtagTMS .|. jtagTDI ,
             jtagLED .|. jtagTMS .|. jtagTDI .|. jtagTCK
           ]

-- TAP controller Reset
jtagTAP_RESET :: [Word8]
jtagTAP_RESET = jtagM1D0 ++ jtagM1D0 ++ jtagM1D0 ++ jtagM1D0 ++ jtagM1D0

-- TAP controller Reset to Idle
jtagTAP_IDLE :: [Word8]
jtagTAP_IDLE = jtagM0D0

-- TAP controller Idle to Shift_DR
jtagTAP_SHIFT_DR :: [Word8]
jtagTAP_SHIFT_DR = jtagM1D0 ++ jtagM0D0 ++ jtagM0D0

-- TAP controller Idle to Shift_IR
jtagTAP_SHIFT_IR :: [Word8]
jtagTAP_SHIFT_IR = jtagM1D0 ++ jtagM1D0 ++ jtagM0D0 ++ jtagM0D0

-- TAP controller Exit1 to Idle
jtagTAP_END_SHIFT :: [Word8]
jtagTAP_END_SHIFT = jtagM1D0 ++ jtagM0D0

-- IR values
jtagSELECT_VIR :: [Word8]
jtagSELECT_VIR = jtagM0D0 ++ jtagM0D1 ++ jtagM0D1 ++ jtagM0D1 ++ jtagM0D0 ++
                 jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM1D0

jtagSELECT_VDR :: [Word8]
jtagSELECT_VDR = jtagM0D0 ++ jtagM0D0 ++ jtagM0D1 ++ jtagM0D1 ++ jtagM0D0 ++
                 jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM1D0

jtagNODE_SHIFT_INST :: [Word8]
jtagNODE_SHIFT_INST  = jtagM0D1 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM1D1

jtagNODE_UPDATE_INST :: [Word8]
jtagNODE_UPDATE_INST = jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM0D0 ++ jtagM1D1

-- Node Datacreate_clock -period 10MHz -name {clk_10} {clk_10}
jtagNODE_DATA :: [Word8]
jtagNODE_DATA = jtagM0D0 ++ jtagM0D1 ++ jtagM0D1 ++ jtagM0D0 ++ jtagM0D0 ++
                jtagM0D1 ++ jtagM1D1

revSplitMsb::[Bool] -> Maybe (Bool, [Bool])
revSplitMsb [] = Nothing
revSplitMsb (x:xs) = Just (x, reverse xs)

mkBytesJtag :: Maybe (Bool, [Bool]) -> [Word8] -> [Word8] -> [Word8] -> [Word8] -> [Word8]
mkBytesJtag msbBits v0 v1 vm0 vm1 =
  case msbBits of
    Nothing -> []
    Just (msb, bits) ->
      join (fmap (\v -> if v then v1 else v0) bits) ++ if msb then vm1 else vm0

jtagWriteBits::DeviceHandle -> [Bool] -> IO Int
jtagWriteBits d bits = ftdiWriteData d $ B.pack $
      mkBytesJtag (revSplitMsb bits) jtagM0D0 jtagM0D1 jtagM1D0 jtagM1D1

lsbToBool :: [Word8] -> [Bool]
lsbToBool b = fmap (\v -> v .&. 1 /= 0) b

jtagWriteReadBits::DeviceHandle -> [Bool] -> IO (Int, [Bool])
jtagWriteReadBits d bits = do
  sz <- ftdiWriteData d $ B.pack $
          mkBytesJtag (revSplitMsb bits) jtagM0D0R jtagM0D1R jtagM1D0R jtagM1D1R
  rd <- ftdiReadData d (length bits)
  case rd of
    Just r -> return (sz, lsbToBool $ B.unpack r)
    _ -> return (sz, [])

tapReset::DeviceHandle -> IO Int
tapReset d = ftdiWriteData d $ B.pack $ jtagTAP_RESET ++ jtagTAP_IDLE

toBits :: (Eq a, Num a, Bits a) => Int -> a -> [Bool]
toBits 0 _ = []
toBits 1 v = [v .&. 1 /= 0]
toBits s v = fmap (\b -> v .&. shift 1 b /= 0) [s - 1, s-2..0]

irWrite::DeviceHandle -> [Bool] -> IO Int
irWrite d b = do
  l <- ftdiWriteData d $ B.pack jtagTAP_SHIFT_IR
  l1 <- jtagWriteBits d b
  l2 <- ftdiWriteData d $ B.pack jtagTAP_END_SHIFT
  return $ l + l1 + l2

virWrite::DeviceHandle -> Word8 -> IO Int
virWrite d addr = do
  -- @todo addr < virAddrBase
  l <- irWrite d $ toBits irAddrLen irAddrVir
  l1 <- ftdiWriteData d $ B.pack jtagTAP_SHIFT_DR
  l2 <- jtagWriteBits d $ toBits virAddrLen $ virAddrBase + addr
  l3 <- ftdiWriteData d $ B.pack jtagTAP_END_SHIFT
  return $ l + l1 + l2 + l3

vdrWrite::DeviceHandle -> [Bool] -> IO Int
vdrWrite d b = do
  l <- irWrite d $ toBits irAddrLen irAddrVdr
  l1 <- ftdiWriteData d $ B.pack jtagTAP_SHIFT_DR
  l2 <- jtagWriteBits d b
  l3 <- ftdiWriteData d $ B.pack jtagTAP_END_SHIFT
  return $ l + l1 + l2 + l3

vdrWriteRead::DeviceHandle -> [Bool] -> IO (Int, [Bool])
vdrWriteRead d b = do
  l <- irWrite d $ toBits irAddrLen irAddrVdr
  l1 <- ftdiWriteData d $ B.pack jtagTAP_SHIFT_DR
  (l2, r) <- jtagWriteReadBits d b
  l3 <- ftdiWriteData d $ B.pack jtagTAP_END_SHIFT
  return (l + l1 + l2 + l3, r)

virAddrWrite, virAddrRead, virAddrOff :: Word8
virAddrWrite = 0x02
virAddrRead  = 0x01
virAddrOff   = 0x00

outLed :: DeviceHandle -> Word32 -> IO Int
outLed d v = do
  l0 <- virWrite d virAddrWrite
  l1 <- vdrWrite d $ toBits 7 v
  l3 <- virWrite d virAddrRead
  (l4, rd) <- vdrWriteRead d $ toBits 7 (0 :: Word8)
  l5 <- virWrite d virAddrOff
  print rd
  threadDelay 20000
  return $ l0 + l1 + l3 + l4 + l5

doStuff :: DeviceHandle -> IO ()
doStuff d = do
  ftdiUSBOpen d (0x09fb, 0x6001)
  ftdiUSBReset d
  _ <- tapReset d
  -- _ <- mapM (outLed d) [0..127]
  _ <- mapM (outLed d) $ join $ replicate 16 [1, 2, 4, 8, 16, 32, 64, 32, 16, 8, 4, 2, 1]
  -- _ <- mapM (outLed d) [127,126..0]
  putStrLn ("Init OK." :: Text)
  ftdiUSBClose d
  ftdiDeInit d

main :: IO ()
main = do
    dh <- ftdiInit
    case dh of
      Left err -> putStrLn $ T.pack $ "Error:" ++ show err
      Right _ -> withFtdi doStuff
