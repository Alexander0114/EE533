VERSION 6
BEGIN SCHEMATIC
    BEGIN ATTR DeviceFamilyName "virtex2p"
        DELETE all:0
        EDITNAME all:0
        EDITTRAIT all:0
    END ATTR
    BEGIN NETLIST
        SIGNAL hwregA(63:0)
        SIGNAL pipe0(71:0)
        SIGNAL pipe0(47:0)
        SIGNAL pipe1(63:0)
        SIGNAL clk
        SIGNAL pipe1(71:0)
        SIGNAL busmerge_output(111:0)
        SIGNAL hwregA(55:0)
        SIGNAL hwregA(62:56)
        SIGNAL XLXN_16
        SIGNAL match_en
        SIGNAL match
        SIGNAL mrst
        SIGNAL XLXN_25
        SIGNAL XLXN_29
        SIGNAL ce
        SIGNAL XLXN_35
        PORT Input hwregA(63:0)
        PORT Input clk
        PORT Input pipe1(71:0)
        PORT Input match_en
        PORT Output match
        PORT Input mrst
        PORT Input ce
        BEGIN BLOCKDEF reg9B
            TIMESTAMP 2026 1 28 22 37 55
            RECTANGLE N 64 -256 320 0 
            LINE N 64 -224 0 -224 
            LINE N 64 -160 0 -160 
            LINE N 64 -96 0 -96 
            RECTANGLE N 0 -44 64 -20 
            LINE N 64 -32 0 -32 
            RECTANGLE N 320 -236 384 -212 
            LINE N 320 -224 384 -224 
        END BLOCKDEF
        BEGIN BLOCKDEF busmerge
            TIMESTAMP 2026 1 28 21 40 48
            RECTANGLE N 64 -128 320 0 
            RECTANGLE N 0 -108 64 -84 
            LINE N 64 -96 0 -96 
            RECTANGLE N 0 -44 64 -20 
            LINE N 64 -32 0 -32 
            RECTANGLE N 320 -108 384 -84 
            LINE N 320 -96 384 -96 
        END BLOCKDEF
        BEGIN BLOCKDEF worldmatch
            TIMESTAMP 2026 1 28 22 37 7
            RECTANGLE N 64 -192 320 0 
            RECTANGLE N 0 -172 64 -148 
            LINE N 64 -160 0 -160 
            RECTANGLE N 0 -108 64 -84 
            LINE N 64 -96 0 -96 
            RECTANGLE N 0 -44 64 -20 
            LINE N 64 -32 0 -32 
            LINE N 320 -160 384 -160 
        END BLOCKDEF
        BEGIN BLOCKDEF fd
            TIMESTAMP 2000 1 1 10 10 10
            RECTANGLE N 64 -320 320 -64 
            LINE N 0 -128 64 -128 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
        END BLOCKDEF
        BEGIN BLOCKDEF and3b1
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -64 40 -64 
            CIRCLE N 40 -76 64 -52 
            LINE N 0 -128 64 -128 
            LINE N 0 -192 64 -192 
            LINE N 256 -128 192 -128 
            LINE N 64 -64 64 -192 
            ARC N 96 -176 192 -80 144 -80 144 -176 
            LINE N 144 -80 64 -80 
            LINE N 64 -176 144 -176 
        END BLOCKDEF
        BEGIN BLOCKDEF fdce
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -128 64 -128 
            LINE N 0 -192 64 -192 
            LINE N 0 -32 64 -32 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            LINE N 64 -112 80 -128 
            LINE N 80 -128 64 -144 
            LINE N 192 -64 192 -32 
            LINE N 192 -32 64 -32 
            RECTANGLE N 64 -320 320 -64 
        END BLOCKDEF
        BEGIN BLOCK XLXI_2 busmerge
            PIN da(47:0) pipe0(47:0)
            PIN db(63:0) pipe1(63:0)
            PIN q(111:0) busmerge_output(111:0)
        END BLOCK
        BEGIN BLOCK XLXI_3 worldmatch
            PIN datain(111:0) busmerge_output(111:0)
            PIN datacomp(55:0) hwregA(55:0)
            PIN wildcard(6:0) hwregA(62:56)
            PIN match XLXN_16
        END BLOCK
        BEGIN BLOCK XLXI_4 fd
            PIN C clk
            PIN D mrst
            PIN Q XLXN_25
        END BLOCK
        BEGIN BLOCK XLXI_5 and3b1
            PIN I0 match
            PIN I1 match_en
            PIN I2 XLXN_16
            PIN O XLXN_35
        END BLOCK
        BEGIN BLOCK XLXI_6 fdce
            PIN C clk
            PIN CE XLXN_35
            PIN CLR XLXN_25
            PIN D XLXN_35
            PIN Q match
        END BLOCK
        BEGIN BLOCK XLXI_1 reg9B
            PIN ce ce
            PIN clk clk
            PIN clr XLXN_25
            PIN d(71:0) pipe1(71:0)
            PIN q(71:0) pipe0(71:0)
        END BLOCK
    END NETLIST
    BEGIN SHEET 1 3520 2720
        BEGIN INSTANCE XLXI_2 672 1184 R0
        END INSTANCE
        BEGIN INSTANCE XLXI_3 1440 1120 R0
        END INSTANCE
        INSTANCE XLXI_4 1952 1744 R0
        INSTANCE XLXI_5 2192 1152 R0
        INSTANCE XLXI_6 2592 1280 R0
        BEGIN BRANCH hwregA(63:0)
            WIRE 432 240 736 240
        END BRANCH
        BEGIN INSTANCE XLXI_1 672 784 R0
        END INSTANCE
        BEGIN BRANCH pipe0(71:0)
            WIRE 1056 560 1168 560
            WIRE 1168 560 1264 560
            BEGIN DISPLAY 1168 560 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH pipe0(47:0)
            WIRE 384 1088 432 1088
            WIRE 432 1088 672 1088
            BEGIN DISPLAY 432 1088 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH pipe1(63:0)
            WIRE 384 1152 432 1152
            WIRE 432 1152 672 1152
            BEGIN DISPLAY 432 1152 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH clk
            WIRE 592 624 640 624
            WIRE 640 624 672 624
            WIRE 640 624 640 1616
            WIRE 640 1616 1488 1616
            WIRE 1488 1616 1952 1616
            WIRE 1488 1152 2592 1152
            WIRE 1488 1152 1488 1616
        END BRANCH
        BEGIN BRANCH pipe1(71:0)
            WIRE 496 752 672 752
        END BRANCH
        BEGIN BRANCH busmerge_output(111:0)
            WIRE 1056 1088 1152 1088
            WIRE 1152 1088 1248 1088
            WIRE 1248 960 1248 1088
            WIRE 1248 960 1440 960
        END BRANCH
        BEGIN BRANCH hwregA(55:0)
            WIRE 1360 1024 1376 1024
            WIRE 1376 1024 1440 1024
            BEGIN DISPLAY 1376 1024 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH hwregA(62:56)
            WIRE 1360 1088 1376 1088
            WIRE 1376 1088 1440 1088
            BEGIN DISPLAY 1376 1088 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH XLXN_16
            WIRE 1824 960 2192 960
        END BRANCH
        BEGIN BRANCH match_en
            WIRE 2016 1024 2192 1024
        END BRANCH
        BEGIN BRANCH match
            WIRE 2112 912 2112 1088
            WIRE 2112 1088 2192 1088
            WIRE 2112 912 3120 912
            WIRE 3120 912 3120 1024
            WIRE 3120 1024 3296 1024
            WIRE 2976 1024 3120 1024
        END BRANCH
        BEGIN BRANCH mrst
            WIRE 1808 1488 1952 1488
        END BRANCH
        IOMARKER 432 240 hwregA(63:0) R180 28
        IOMARKER 496 752 pipe1(71:0) R180 28
        IOMARKER 2016 1024 match_en R180 28
        IOMARKER 1808 1488 mrst R180 28
        IOMARKER 3296 1024 match R0 28
        IOMARKER 592 624 clk R180 28
        BEGIN BRANCH XLXN_25
            WIRE 592 688 672 688
            WIRE 592 688 592 1840
            WIRE 592 1840 2464 1840
            WIRE 2336 1488 2464 1488
            WIRE 2464 1488 2592 1488
            WIRE 2464 1488 2464 1840
            WIRE 2592 1248 2592 1488
        END BRANCH
        BEGIN BRANCH ce
            WIRE 432 560 672 560
        END BRANCH
        IOMARKER 432 560 ce R180 28
        BEGIN BRANCH XLXN_35
            WIRE 2448 1024 2480 1024
            WIRE 2480 1024 2592 1024
            WIRE 2480 1024 2480 1088
            WIRE 2480 1088 2592 1088
        END BRANCH
    END SHEET
END SCHEMATIC
