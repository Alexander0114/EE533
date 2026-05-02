VERSION 6
BEGIN SCHEMATIC
    BEGIN ATTR DeviceFamilyName "virtex2p"
        DELETE all:0
        EDITNAME all:0
        EDITTRAIT all:0
    END ATTR
    BEGIN NETLIST
        SIGNAL ce
        SIGNAL clk
        SIGNAL clr
        SIGNAL d(71:0)
        SIGNAL q(71:0)
        SIGNAL d(71:64)
        SIGNAL d(63:48)
        SIGNAL d(47:32)
        SIGNAL d(31:16)
        SIGNAL d(15:0)
        SIGNAL q(71:64)
        SIGNAL q(63:48)
        SIGNAL q(47:32)
        SIGNAL q(31:16)
        SIGNAL q(15:0)
        SIGNAL XLXN_16
        SIGNAL XLXN_17
        SIGNAL XLXN_18
        PORT Input ce
        PORT Input clk
        PORT Input clr
        PORT Input d(71:0)
        PORT Output q(71:0)
        BEGIN BLOCKDEF fd8ce
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -128 64 -128 
            LINE N 0 -192 64 -192 
            LINE N 0 -32 64 -32 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            LINE N 192 -32 64 -32 
            LINE N 192 -64 192 -32 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
            RECTANGLE N 320 -268 384 -244 
            RECTANGLE N 0 -268 64 -244 
            RECTANGLE N 64 -320 320 -64 
        END BLOCKDEF
        BEGIN BLOCKDEF fd16ce
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -128 64 -128 
            LINE N 0 -192 64 -192 
            LINE N 0 -32 64 -32 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
            RECTANGLE N 320 -268 384 -244 
            RECTANGLE N 0 -268 64 -244 
            LINE N 192 -32 64 -32 
            LINE N 192 -64 192 -32 
            RECTANGLE N 64 -320 320 -64 
        END BLOCKDEF
        BEGIN BLOCK XLXI_1 fd8ce
            PIN C clk
            PIN CE ce
            PIN CLR clr
            PIN D(7:0) d(71:64)
            PIN Q(7:0) q(71:64)
        END BLOCK
        BEGIN BLOCK XLXI_6 fd16ce
            PIN C clk
            PIN CE ce
            PIN CLR clr
            PIN D(15:0) d(63:48)
            PIN Q(15:0) q(63:48)
        END BLOCK
        BEGIN BLOCK XLXI_7 fd16ce
            PIN C clk
            PIN CE ce
            PIN CLR clr
            PIN D(15:0) d(47:32)
            PIN Q(15:0) q(47:32)
        END BLOCK
        BEGIN BLOCK XLXI_8 fd16ce
            PIN C clk
            PIN CE ce
            PIN CLR clr
            PIN D(15:0) d(31:16)
            PIN Q(15:0) q(31:16)
        END BLOCK
        BEGIN BLOCK XLXI_9 fd16ce
            PIN C clk
            PIN CE ce
            PIN CLR clr
            PIN D(15:0) d(15:0)
            PIN Q(15:0) q(15:0)
        END BLOCK
    END NETLIST
    BEGIN SHEET 1 3520 2720
        INSTANCE XLXI_1 1328 528 R0
        BEGIN BRANCH ce
            WIRE 688 1904 784 1904
            WIRE 784 1904 1184 1904
            WIRE 1184 336 1328 336
            WIRE 1184 336 1184 720
            WIRE 1184 720 1328 720
            WIRE 1184 720 1184 1104
            WIRE 1184 1104 1328 1104
            WIRE 1184 1104 1184 1456
            WIRE 1184 1456 1328 1456
            WIRE 1184 1456 1184 1808
            WIRE 1184 1808 1184 1904
            WIRE 1184 1808 1328 1808
        END BRANCH
        BEGIN BRANCH clk
            WIRE 688 2032 784 2032
            WIRE 784 2032 1232 2032
            WIRE 1232 400 1328 400
            WIRE 1232 400 1232 784
            WIRE 1232 784 1328 784
            WIRE 1232 784 1232 1168
            WIRE 1232 1168 1328 1168
            WIRE 1232 1168 1232 1520
            WIRE 1232 1520 1328 1520
            WIRE 1232 1520 1232 1872
            WIRE 1232 1872 1232 2032
            WIRE 1232 1872 1328 1872
        END BRANCH
        BEGIN BRANCH clr
            WIRE 688 2144 784 2144
            WIRE 784 2144 1328 2144
            WIRE 1296 528 1296 912
            WIRE 1296 912 1312 912
            WIRE 1312 912 1312 1280
            WIRE 1296 528 1328 528
            WIRE 1296 1264 1328 1264
            WIRE 1296 1264 1296 1280
            WIRE 1296 1280 1296 1632
            WIRE 1296 1632 1312 1632
            WIRE 1312 1632 1312 2016
            WIRE 1312 2016 1328 2016
            WIRE 1328 2016 1328 2144
            WIRE 1296 1280 1312 1280
            WIRE 1312 880 1328 880
            WIRE 1312 880 1312 912
            WIRE 1312 1616 1328 1616
            WIRE 1312 1616 1312 1632
            WIRE 1328 496 1328 528
            WIRE 1328 1968 1328 2016
        END BRANCH
        BEGIN BRANCH d(71:0)
            WIRE 1008 2320 1424 2320
        END BRANCH
        BEGIN BRANCH q(71:0)
            WIRE 1904 2320 2320 2320
        END BRANCH
        IOMARKER 688 1904 ce R180 28
        IOMARKER 688 2032 clk R180 28
        IOMARKER 688 2144 clr R180 28
        IOMARKER 1008 2320 d(71:0) R180 28
        IOMARKER 2320 2320 q(71:0) R0 28
        BEGIN BRANCH d(71:64)
            WIRE 976 272 1040 272
            WIRE 1040 272 1328 272
            BEGIN DISPLAY 1040 272 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH d(63:48)
            WIRE 976 656 1008 656
            WIRE 1008 656 1328 656
            BEGIN DISPLAY 1008 656 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH d(47:32)
            WIRE 976 1040 1024 1040
            WIRE 1024 1040 1328 1040
            BEGIN DISPLAY 1024 1040 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH d(31:16)
            WIRE 992 1392 1040 1392
            WIRE 1040 1392 1328 1392
            BEGIN DISPLAY 1040 1392 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH d(15:0)
            WIRE 992 1744 1024 1744
            WIRE 1024 1744 1328 1744
            BEGIN DISPLAY 1024 1744 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH q(71:64)
            WIRE 1712 272 1856 272
            WIRE 1856 272 1920 272
            BEGIN DISPLAY 1856 272 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH q(63:48)
            WIRE 1712 656 1856 656
            WIRE 1856 656 1920 656
            BEGIN DISPLAY 1856 656 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH q(47:32)
            WIRE 1712 1040 1856 1040
            WIRE 1856 1040 1920 1040
            BEGIN DISPLAY 1856 1040 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH q(31:16)
            WIRE 1712 1392 1872 1392
            WIRE 1872 1392 1920 1392
            BEGIN DISPLAY 1872 1392 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH q(15:0)
            WIRE 1712 1744 1840 1744
            WIRE 1840 1744 1920 1744
            BEGIN DISPLAY 1840 1744 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        INSTANCE XLXI_6 1328 912 R0
        INSTANCE XLXI_7 1328 1296 R0
        INSTANCE XLXI_8 1328 1648 R0
        INSTANCE XLXI_9 1328 2000 R0
    END SHEET
END SCHEMATIC
