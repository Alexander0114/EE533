VERSION 6
BEGIN SCHEMATIC
    BEGIN ATTR DeviceFamilyName "virtex2p"
        DELETE all:0
        EDITNAME all:0
        EDITTRAIT all:0
    END ATTR
    BEGIN NETLIST
        SIGNAL datain(111:0)
        SIGNAL XLXN_3(55:0)
        SIGNAL XLXN_4(55:0)
        SIGNAL XLXN_5(55:0)
        SIGNAL XLXN_6(55:0)
        SIGNAL XLXN_7(55:0)
        SIGNAL XLXN_8(55:0)
        SIGNAL datacomp(55:0)
        SIGNAL XLXN_10(55:0)
        SIGNAL XLXN_11(55:0)
        SIGNAL XLXN_12(55:0)
        SIGNAL XLXN_14(55:0)
        SIGNAL XLXN_15(55:0)
        SIGNAL XLXN_17(55:0)
        SIGNAL XLXN_18(55:0)
        SIGNAL wildcard(6:0)
        SIGNAL XLXN_20(6:0)
        SIGNAL XLXN_21(6:0)
        SIGNAL XLXN_22(6:0)
        SIGNAL XLXN_23(6:0)
        SIGNAL XLXN_24(6:0)
        SIGNAL XLXN_25(6:0)
        SIGNAL XLXN_26(6:0)
        SIGNAL datain(55:0)
        SIGNAL datain(63:8)
        SIGNAL datain(71:16)
        SIGNAL datain(79:24)
        SIGNAL datain(87:32)
        SIGNAL datain(95:40)
        SIGNAL datain(103:48)
        SIGNAL datain(111:56)
        SIGNAL XLXN_35
        SIGNAL XLXN_36
        SIGNAL XLXN_37
        SIGNAL XLXN_38
        SIGNAL XLXN_39
        SIGNAL XLXN_40
        SIGNAL XLXN_41
        SIGNAL XLXN_42
        SIGNAL match
        PORT Input datain(111:0)
        PORT Input datacomp(55:0)
        PORT Input wildcard(6:0)
        PORT Output match
        BEGIN BLOCKDEF comparator
            TIMESTAMP 2026 1 28 22 20 47
            RECTANGLE N 64 -192 320 0 
            RECTANGLE N 0 -172 64 -148 
            LINE N 64 -160 0 -160 
            RECTANGLE N 0 -108 64 -84 
            LINE N 64 -96 0 -96 
            RECTANGLE N 0 -44 64 -20 
            LINE N 64 -32 0 -32 
            LINE N 320 -160 384 -160 
        END BLOCKDEF
        BEGIN BLOCKDEF or8
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -64 48 -64 
            LINE N 0 -128 48 -128 
            LINE N 0 -192 48 -192 
            LINE N 0 -384 48 -384 
            LINE N 0 -448 48 -448 
            LINE N 0 -512 48 -512 
            LINE N 256 -288 192 -288 
            LINE N 0 -320 64 -320 
            LINE N 0 -256 64 -256 
            ARC N 28 -336 204 -160 192 -288 112 -336 
            LINE N 112 -240 48 -240 
            ARC N 28 -416 204 -240 112 -240 192 -288 
            ARC N -40 -344 72 -232 48 -240 48 -336 
            LINE N 112 -336 48 -336 
            LINE N 48 -336 48 -512 
            LINE N 48 -64 48 -240 
        END BLOCKDEF
        BEGIN BLOCK XLXI_1 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(55:0)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_35
        END BLOCK
        BEGIN BLOCK XLXI_2 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(63:8)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_36
        END BLOCK
        BEGIN BLOCK XLXI_3 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(71:16)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_37
        END BLOCK
        BEGIN BLOCK XLXI_4 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(79:24)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_38
        END BLOCK
        BEGIN BLOCK XLXI_5 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(87:32)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_39
        END BLOCK
        BEGIN BLOCK XLXI_6 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(95:40)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_40
        END BLOCK
        BEGIN BLOCK XLXI_7 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(103:48)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_41
        END BLOCK
        BEGIN BLOCK XLXI_8 comparator
            PIN a(55:0) datacomp(55:0)
            PIN b(55:0) datain(111:56)
            PIN amask(6:0) wildcard(6:0)
            PIN match XLXN_42
        END BLOCK
        BEGIN BLOCK XLXI_17 or8
            PIN I0 XLXN_42
            PIN I1 XLXN_41
            PIN I2 XLXN_40
            PIN I3 XLXN_39
            PIN I4 XLXN_38
            PIN I5 XLXN_37
            PIN I6 XLXN_36
            PIN I7 XLXN_35
            PIN O match
        END BLOCK
    END NETLIST
    BEGIN SHEET 1 3520 2720
        BEGIN INSTANCE XLXI_1 1248 464 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_2 1248 768 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_3 1248 1072 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_4 1248 1376 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_5 1264 1680 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_6 1264 1984 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_7 1264 2288 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_8 1264 2592 R0
        END INSTANCE
        BEGIN BRANCH datain(111:0)
            WIRE 640 96 896 96
        END BRANCH
        INSTANCE XLXI_17 2464 1728 R0
        IOMARKER 640 96 datain(111:0) R180 28
        IOMARKER 640 304 datacomp(55:0) R180 28
        BEGIN BRANCH datacomp(55:0)
            WIRE 640 304 1024 304
            WIRE 1024 304 1248 304
            WIRE 1024 304 1024 592
            WIRE 1024 592 1024 608
            WIRE 1024 608 1248 608
            WIRE 1024 608 1024 912
            WIRE 1024 912 1248 912
            WIRE 1024 912 1024 1216
            WIRE 1024 1216 1248 1216
            WIRE 1024 1216 1024 1520
            WIRE 1024 1520 1264 1520
            WIRE 1024 1520 1024 1824
            WIRE 1024 1824 1264 1824
            WIRE 1024 1824 1024 2128
            WIRE 1024 2128 1264 2128
            WIRE 1024 2128 1024 2432
            WIRE 1024 2432 1264 2432
        END BRANCH
        BEGIN BRANCH wildcard(6:0)
            WIRE 640 432 1056 432
            WIRE 1056 432 1248 432
            WIRE 1056 432 1056 736
            WIRE 1056 736 1248 736
            WIRE 1056 736 1056 1040
            WIRE 1056 1040 1248 1040
            WIRE 1056 1040 1056 1344
            WIRE 1056 1344 1248 1344
            WIRE 1056 1344 1056 1648
            WIRE 1056 1648 1264 1648
            WIRE 1056 1648 1056 1952
            WIRE 1056 1952 1264 1952
            WIRE 1056 1952 1056 2256
            WIRE 1056 2256 1264 2256
            WIRE 1056 2256 1056 2560
            WIRE 1056 2560 1264 2560
        END BRANCH
        IOMARKER 640 432 wildcard(6:0) R180 28
        BEGIN BRANCH datain(55:0)
            WIRE 880 368 928 368
            WIRE 928 368 1248 368
            BEGIN DISPLAY 928 368 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(63:8)
            WIRE 896 672 912 672
            WIRE 912 672 1248 672
            BEGIN DISPLAY 912 672 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(71:16)
            WIRE 912 976 944 976
            WIRE 944 976 1248 976
            BEGIN DISPLAY 944 976 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(79:24)
            WIRE 912 1280 928 1280
            WIRE 928 1280 1248 1280
            BEGIN DISPLAY 928 1280 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(87:32)
            WIRE 912 1584 944 1584
            WIRE 944 1584 1264 1584
            BEGIN DISPLAY 944 1584 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(95:40)
            WIRE 928 1888 960 1888
            WIRE 960 1888 1264 1888
            BEGIN DISPLAY 960 1888 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(103:48)
            WIRE 928 2192 960 2192
            WIRE 960 2192 1264 2192
            BEGIN DISPLAY 960 2192 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH datain(111:56)
            WIRE 944 2496 992 2496
            WIRE 992 2496 1264 2496
            BEGIN DISPLAY 992 2496 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH XLXN_35
            WIRE 1632 304 2464 304
            WIRE 2464 304 2464 1216
        END BRANCH
        BEGIN BRANCH XLXN_36
            WIRE 1632 608 2048 608
            WIRE 2048 608 2048 1280
            WIRE 2048 1280 2464 1280
        END BRANCH
        BEGIN BRANCH XLXN_37
            WIRE 1632 912 2032 912
            WIRE 2032 912 2032 1344
            WIRE 2032 1344 2464 1344
        END BRANCH
        BEGIN BRANCH XLXN_38
            WIRE 1632 1216 2016 1216
            WIRE 2016 1216 2016 1408
            WIRE 2016 1408 2464 1408
        END BRANCH
        BEGIN BRANCH XLXN_39
            WIRE 1648 1520 2048 1520
            WIRE 2048 1472 2048 1520
            WIRE 2048 1472 2464 1472
        END BRANCH
        BEGIN BRANCH XLXN_40
            WIRE 1648 1824 2048 1824
            WIRE 2048 1536 2048 1824
            WIRE 2048 1536 2464 1536
        END BRANCH
        BEGIN BRANCH XLXN_41
            WIRE 1648 2128 2064 2128
            WIRE 2064 1600 2064 2128
            WIRE 2064 1600 2464 1600
        END BRANCH
        BEGIN BRANCH XLXN_42
            WIRE 1648 2432 2464 2432
            WIRE 2464 1664 2464 2432
        END BRANCH
        BEGIN BRANCH match
            WIRE 2720 1440 2736 1440
            WIRE 2736 1440 2960 1440
        END BRANCH
        IOMARKER 2960 1440 match R0 28
    END SHEET
END SCHEMATIC
