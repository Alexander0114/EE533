VERSION 6
BEGIN SCHEMATIC
    BEGIN ATTR DeviceFamilyName "virtex2p"
        DELETE all:0
        EDITNAME all:0
        EDITTRAIT all:0
    END ATTR
    BEGIN NETLIST
        SIGNAL a(55:0)
        SIGNAL b(55:0)
        SIGNAL amask(6:0)
        SIGNAL a(55:48)
        SIGNAL b(55:48)
        SIGNAL a(47:40)
        SIGNAL b(47:40)
        SIGNAL a(39:32)
        SIGNAL b(39:32)
        SIGNAL a(31:24)
        SIGNAL b(31:24)
        SIGNAL a(23:16)
        SIGNAL b(23:16)
        SIGNAL a(15:8)
        SIGNAL b(15:8)
        SIGNAL a(7:0)
        SIGNAL b(7:0)
        SIGNAL match
        SIGNAL XLXN_20
        SIGNAL XLXN_21
        SIGNAL XLXN_22
        SIGNAL XLXN_23
        SIGNAL XLXN_24
        SIGNAL XLXN_25
        SIGNAL XLXN_26
        SIGNAL amask(6)
        SIGNAL amask(5)
        SIGNAL amask(4)
        SIGNAL amask(3)
        SIGNAL amask(2)
        SIGNAL amask(1)
        SIGNAL amask(0)
        SIGNAL XLXN_34
        SIGNAL XLXN_35
        SIGNAL XLXN_36
        SIGNAL XLXN_37
        SIGNAL XLXN_38
        SIGNAL XLXN_39
        SIGNAL XLXN_40
        PORT Input a(55:0)
        PORT Input b(55:0)
        PORT Input amask(6:0)
        PORT Output match
        BEGIN BLOCKDEF comp8
            TIMESTAMP 2000 1 1 10 10 10
            RECTANGLE N 64 -384 320 -64 
            LINE N 384 -224 320 -224 
            RECTANGLE N 0 -332 64 -308 
            LINE N 0 -320 64 -320 
            RECTANGLE N 0 -140 64 -116 
            LINE N 0 -128 64 -128 
        END BLOCKDEF
        BEGIN BLOCKDEF or2b1
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -64 32 -64 
            CIRCLE N 32 -76 56 -52 
            LINE N 0 -128 64 -128 
            LINE N 256 -96 192 -96 
            LINE N 112 -48 48 -48 
            ARC N 28 -144 204 32 192 -96 112 -144 
            LINE N 112 -144 48 -144 
            ARC N -40 -152 72 -40 48 -48 48 -144 
            ARC N 28 -224 204 -48 112 -48 192 -96 
        END BLOCKDEF
        BEGIN BLOCKDEF and7
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 64 -448 64 -64 
            ARC N 96 -304 192 -208 144 -208 144 -304 
            LINE N 64 -304 144 -304 
            LINE N 144 -208 64 -208 
            LINE N 256 -256 192 -256 
            LINE N 0 -448 64 -448 
            LINE N 0 -384 64 -384 
            LINE N 0 -320 64 -320 
            LINE N 0 -256 64 -256 
            LINE N 0 -192 64 -192 
            LINE N 0 -128 64 -128 
            LINE N 0 -64 64 -64 
        END BLOCKDEF
        BEGIN BLOCK XLXI_1 comp8
            PIN A(7:0) a(55:48)
            PIN B(7:0) b(55:48)
            PIN EQ XLXN_20
        END BLOCK
        BEGIN BLOCK XLXI_2 comp8
            PIN A(7:0) a(47:40)
            PIN B(7:0) b(47:40)
            PIN EQ XLXN_21
        END BLOCK
        BEGIN BLOCK XLXI_3 comp8
            PIN A(7:0) a(39:32)
            PIN B(7:0) b(39:32)
            PIN EQ XLXN_22
        END BLOCK
        BEGIN BLOCK XLXI_4 comp8
            PIN A(7:0) a(31:24)
            PIN B(7:0) b(31:24)
            PIN EQ XLXN_23
        END BLOCK
        BEGIN BLOCK XLXI_5 comp8
            PIN A(7:0) a(23:16)
            PIN B(7:0) b(23:16)
            PIN EQ XLXN_24
        END BLOCK
        BEGIN BLOCK XLXI_6 comp8
            PIN A(7:0) a(15:8)
            PIN B(7:0) b(15:8)
            PIN EQ XLXN_25
        END BLOCK
        BEGIN BLOCK XLXI_7 comp8
            PIN A(7:0) a(7:0)
            PIN B(7:0) b(7:0)
            PIN EQ XLXN_26
        END BLOCK
        BEGIN BLOCK XLXI_8 or2b1
            PIN I0 amask(6)
            PIN I1 XLXN_20
            PIN O XLXN_34
        END BLOCK
        BEGIN BLOCK XLXI_9 or2b1
            PIN I0 amask(5)
            PIN I1 XLXN_21
            PIN O XLXN_35
        END BLOCK
        BEGIN BLOCK XLXI_10 or2b1
            PIN I0 amask(4)
            PIN I1 XLXN_22
            PIN O XLXN_36
        END BLOCK
        BEGIN BLOCK XLXI_11 or2b1
            PIN I0 amask(3)
            PIN I1 XLXN_23
            PIN O XLXN_37
        END BLOCK
        BEGIN BLOCK XLXI_12 or2b1
            PIN I0 amask(2)
            PIN I1 XLXN_24
            PIN O XLXN_38
        END BLOCK
        BEGIN BLOCK XLXI_13 or2b1
            PIN I0 amask(1)
            PIN I1 XLXN_25
            PIN O XLXN_39
        END BLOCK
        BEGIN BLOCK XLXI_14 or2b1
            PIN I0 amask(0)
            PIN I1 XLXN_26
            PIN O XLXN_40
        END BLOCK
        BEGIN BLOCK XLXI_15 and7
            PIN I0 XLXN_40
            PIN I1 XLXN_39
            PIN I2 XLXN_38
            PIN I3 XLXN_37
            PIN I4 XLXN_36
            PIN I5 XLXN_35
            PIN I6 XLXN_34
            PIN O match
        END BLOCK
    END NETLIST
    BEGIN SHEET 1 3520 2720
        BEGIN BRANCH a(55:0)
            WIRE 480 272 768 272
        END BRANCH
        BEGIN BRANCH b(55:0)
            WIRE 480 416 752 416
        END BRANCH
        BEGIN BRANCH amask(6:0)
            WIRE 1040 272 1312 272
        END BRANCH
        IOMARKER 480 272 a(55:0) R180 28
        IOMARKER 480 416 b(55:0) R180 28
        IOMARKER 1040 272 amask(6:0) R180 28
        INSTANCE XLXI_1 640 1056 R0
        INSTANCE XLXI_2 640 1488 R0
        INSTANCE XLXI_3 640 1920 R0
        INSTANCE XLXI_4 640 2368 R0
        INSTANCE XLXI_5 1696 1056 R0
        INSTANCE XLXI_6 1696 1488 R0
        INSTANCE XLXI_7 1696 1920 R0
        BEGIN BRANCH a(55:48)
            WIRE 400 736 432 736
            WIRE 432 736 640 736
            BEGIN DISPLAY 432 736 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(55:48)
            WIRE 400 928 432 928
            WIRE 432 928 640 928
            BEGIN DISPLAY 432 928 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(47:40)
            WIRE 400 1168 416 1168
            WIRE 416 1168 640 1168
            BEGIN DISPLAY 416 1168 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(47:40)
            WIRE 400 1360 432 1360
            WIRE 432 1360 640 1360
            BEGIN DISPLAY 432 1360 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(39:32)
            WIRE 400 1600 448 1600
            WIRE 448 1600 640 1600
            BEGIN DISPLAY 448 1600 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(39:32)
            WIRE 400 1792 432 1792
            WIRE 432 1792 640 1792
            BEGIN DISPLAY 432 1792 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(31:24)
            WIRE 400 2048 432 2048
            WIRE 432 2048 640 2048
            BEGIN DISPLAY 432 2048 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(31:24)
            WIRE 400 2240 432 2240
            WIRE 432 2240 640 2240
            BEGIN DISPLAY 432 2240 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(23:16)
            WIRE 1504 736 1536 736
            WIRE 1536 736 1696 736
            BEGIN DISPLAY 1536 736 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(23:16)
            WIRE 1520 928 1536 928
            WIRE 1536 928 1696 928
            BEGIN DISPLAY 1536 928 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(15:8)
            WIRE 1504 1168 1552 1168
            WIRE 1552 1168 1696 1168
            BEGIN DISPLAY 1552 1168 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(15:8)
            WIRE 1504 1360 1536 1360
            WIRE 1536 1360 1696 1360
            BEGIN DISPLAY 1536 1360 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH a(7:0)
            WIRE 1520 1600 1536 1600
            WIRE 1536 1600 1696 1600
            BEGIN DISPLAY 1536 1600 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH b(7:0)
            WIRE 1520 1792 1552 1792
            WIRE 1552 1792 1696 1792
            BEGIN DISPLAY 1552 1792 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        INSTANCE XLXI_8 1120 960 R0
        INSTANCE XLXI_9 1120 1392 R0
        INSTANCE XLXI_10 1120 1824 R0
        INSTANCE XLXI_11 1120 2272 R0
        INSTANCE XLXI_12 2256 960 R0
        INSTANCE XLXI_13 2272 1392 R0
        INSTANCE XLXI_14 2288 1824 R0
        INSTANCE XLXI_15 2832 1744 R0
        BEGIN BRANCH match
            WIRE 3088 1488 3264 1488
        END BRANCH
        IOMARKER 3264 1488 match R0 28
        BEGIN BRANCH XLXN_20
            WIRE 1024 832 1120 832
        END BRANCH
        BEGIN BRANCH XLXN_21
            WIRE 1024 1264 1120 1264
        END BRANCH
        BEGIN BRANCH XLXN_22
            WIRE 1024 1696 1120 1696
        END BRANCH
        BEGIN BRANCH XLXN_23
            WIRE 1024 2144 1120 2144
        END BRANCH
        BEGIN BRANCH XLXN_24
            WIRE 2080 832 2256 832
        END BRANCH
        BEGIN BRANCH XLXN_25
            WIRE 2080 1264 2272 1264
        END BRANCH
        BEGIN BRANCH XLXN_26
            WIRE 2080 1696 2288 1696
        END BRANCH
        BEGIN BRANCH amask(6)
            WIRE 1072 896 1088 896
            WIRE 1088 896 1120 896
            BEGIN DISPLAY 1088 896 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(5)
            WIRE 1056 1328 1072 1328
            WIRE 1072 1328 1120 1328
            BEGIN DISPLAY 1072 1328 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(4)
            WIRE 1056 1760 1072 1760
            WIRE 1072 1760 1120 1760
            BEGIN DISPLAY 1072 1760 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(3)
            WIRE 1040 2208 1072 2208
            WIRE 1072 2208 1120 2208
            BEGIN DISPLAY 1072 2208 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(2)
            WIRE 2144 896 2176 896
            WIRE 2176 896 2256 896
            BEGIN DISPLAY 2176 896 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(1)
            WIRE 2160 1328 2192 1328
            WIRE 2192 1328 2272 1328
            BEGIN DISPLAY 2192 1328 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH amask(0)
            WIRE 2176 1760 2208 1760
            WIRE 2208 1760 2288 1760
            BEGIN DISPLAY 2208 1760 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH XLXN_34
            WIRE 1376 864 1456 864
            WIRE 1456 592 1456 864
            WIRE 1456 592 2832 592
            WIRE 2832 592 2832 1296
        END BRANCH
        BEGIN BRANCH XLXN_35
            WIRE 1376 1296 1456 1296
            WIRE 1456 1296 1456 1488
            WIRE 1456 1488 2144 1488
            WIRE 2144 1360 2144 1488
            WIRE 2144 1360 2832 1360
        END BRANCH
        BEGIN BRANCH XLXN_36
            WIRE 1376 1728 1456 1728
            WIRE 1456 1728 1456 1936
            WIRE 1456 1936 2160 1936
            WIRE 2160 1424 2160 1936
            WIRE 2160 1424 2832 1424
        END BRANCH
        BEGIN BRANCH XLXN_37
            WIRE 1376 2176 2192 2176
            WIRE 2192 1488 2192 2176
            WIRE 2192 1488 2832 1488
        END BRANCH
        BEGIN BRANCH XLXN_38
            WIRE 2512 864 2672 864
            WIRE 2672 864 2672 1552
            WIRE 2672 1552 2832 1552
        END BRANCH
        BEGIN BRANCH XLXN_39
            WIRE 2528 1296 2656 1296
            WIRE 2656 1296 2656 1616
            WIRE 2656 1616 2832 1616
        END BRANCH
        BEGIN BRANCH XLXN_40
            WIRE 2544 1728 2832 1728
            WIRE 2832 1680 2832 1728
        END BRANCH
    END SHEET
END SCHEMATIC
