VERSION 6
BEGIN SCHEMATIC
    BEGIN ATTR DeviceFamilyName "virtex2p"
        DELETE all:0
        EDITNAME all:0
        EDITTRAIT all:0
    END ATTR
    BEGIN NETLIST
        SIGNAL drop_pkt
        SIGNAL clk
        SIGNAL lastword
        SIGNAL firstword
        SIGNAL valid_data
        SIGNAL in_fifo(71:0)
        SIGNAL fifowrite
        SIGNAL rst
        SIGNAL XLXN_11
        SIGNAL XLXN_12
        SIGNAL fiforead
        SIGNAL XLXN_14
        SIGNAL XLXN_15
        SIGNAL XLXN_16
        SIGNAL XLXN_17
        SIGNAL XLXN_18
        SIGNAL XLXN_19
        SIGNAL raddr(7:0)
        SIGNAL waddr(7:0)
        SIGNAL XLXN_25(71:0)
        SIGNAL XLXN_33
        SIGNAL XLXN_34(0:0)
        SIGNAL XLXN_49
        SIGNAL out_fifo(71:0)
        SIGNAL XLXN_51(7:0)
        SIGNAL XLXN_52
        SIGNAL XLXN_53
        SIGNAL XLXN_56(7:0)
        SIGNAL XLXN_57(7:0)
        SIGNAL XLXN_59(7:0)
        SIGNAL XLXN_60(7:0)
        SIGNAL XLXN_61(7:0)
        SIGNAL XLXN_62(7:0)
        PORT Input drop_pkt
        PORT Input clk
        PORT Input lastword
        PORT Input firstword
        PORT Output valid_data
        PORT Input in_fifo(71:0)
        PORT Input fifowrite
        PORT Input rst
        PORT Input fiforead
        PORT Output out_fifo(71:0)
        BEGIN BLOCKDEF fd
            TIMESTAMP 2000 1 1 10 10 10
            RECTANGLE N 64 -320 320 -64 
            LINE N 0 -128 64 -128 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
        END BLOCKDEF
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
        BEGIN BLOCKDEF cb8cle
            TIMESTAMP 2000 1 1 10 10 10
            RECTANGLE N 64 -448 320 -64 
            LINE N 0 -192 64 -192 
            LINE N 192 -32 64 -32 
            LINE N 192 -64 192 -32 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
            LINE N 0 -128 64 -128 
            LINE N 0 -32 64 -32 
            LINE N 0 -256 64 -256 
            LINE N 0 -384 64 -384 
            RECTANGLE N 0 -396 64 -372 
            LINE N 384 -384 320 -384 
            LINE N 384 -192 320 -192 
            RECTANGLE N 320 -396 384 -372 
            LINE N 384 -128 320 -128 
        END BLOCKDEF
        BEGIN BLOCKDEF cb8ce
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 384 -128 320 -128 
            RECTANGLE N 320 -268 384 -244 
            LINE N 384 -256 320 -256 
            LINE N 0 -192 64 -192 
            LINE N 192 -32 64 -32 
            LINE N 192 -64 192 -32 
            LINE N 80 -128 64 -144 
            LINE N 64 -112 80 -128 
            LINE N 0 -128 64 -128 
            LINE N 0 -32 64 -32 
            LINE N 384 -192 320 -192 
            RECTANGLE N 64 -320 320 -64 
        END BLOCKDEF
        BEGIN BLOCKDEF fdc
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -128 64 -128 
            LINE N 0 -32 64 -32 
            LINE N 0 -256 64 -256 
            LINE N 384 -256 320 -256 
            RECTANGLE N 64 -320 320 -64 
            LINE N 64 -112 80 -128 
            LINE N 80 -128 64 -144 
            LINE N 192 -64 192 -32 
            LINE N 192 -32 64 -32 
        END BLOCKDEF
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
        BEGIN BLOCKDEF comp8
            TIMESTAMP 2000 1 1 10 10 10
            RECTANGLE N 64 -384 320 -64 
            LINE N 384 -224 320 -224 
            RECTANGLE N 0 -332 64 -308 
            LINE N 0 -320 64 -320 
            RECTANGLE N 0 -140 64 -116 
            LINE N 0 -128 64 -128 
        END BLOCKDEF
        BEGIN BLOCKDEF or2
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -64 64 -64 
            LINE N 0 -128 64 -128 
            LINE N 256 -96 192 -96 
            ARC N 28 -224 204 -48 112 -48 192 -96 
            ARC N -40 -152 72 -40 48 -48 48 -144 
            LINE N 112 -144 48 -144 
            ARC N 28 -144 204 32 192 -96 112 -144 
            LINE N 112 -48 48 -48 
        END BLOCKDEF
        BEGIN BLOCKDEF and2b1
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 64 -48 64 -144 
            LINE N 64 -144 144 -144 
            LINE N 144 -48 64 -48 
            ARC N 96 -144 192 -48 144 -48 144 -144 
            LINE N 256 -96 192 -96 
            LINE N 0 -128 64 -128 
            LINE N 0 -64 40 -64 
            CIRCLE N 40 -76 64 -52 
        END BLOCKDEF
        BEGIN BLOCKDEF and3b2
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 0 -64 40 -64 
            CIRCLE N 40 -76 64 -52 
            LINE N 0 -128 40 -128 
            CIRCLE N 40 -140 64 -116 
            LINE N 0 -192 64 -192 
            LINE N 256 -128 192 -128 
            LINE N 64 -64 64 -192 
            ARC N 96 -176 192 -80 144 -80 144 -176 
            LINE N 144 -80 64 -80 
            LINE N 64 -176 144 -176 
        END BLOCKDEF
        BEGIN BLOCKDEF vcc
            TIMESTAMP 2000 1 1 10 10 10
            LINE N 64 -32 64 -64 
            LINE N 64 0 64 -32 
            LINE N 96 -64 32 -64 
        END BLOCKDEF
        BEGIN BLOCKDEF old_dp_72_256k
            TIMESTAMP 2026 1 30 6 45 9
            RECTANGLE N 32 0 256 496 
            BEGIN LINE W 0 48 32 48 
            END LINE
            BEGIN LINE W 0 80 32 80 
            END LINE
            LINE N 0 112 32 112 
            LINE N 0 240 32 240 
            BEGIN LINE W 0 272 32 272 
            END LINE
            LINE N 0 464 32 464 
            BEGIN LINE W 256 272 288 272 
            END LINE
        END BLOCKDEF
        BEGIN BLOCK XLXI_4 fd
            PIN C clk
            PIN D firstword
            PIN Q XLXN_14
        END BLOCK
        BEGIN BLOCK XLXI_5 fd
            PIN C clk
            PIN D lastword
            PIN Q XLXN_15
        END BLOCK
        BEGIN BLOCK XLXI_7 fd
            PIN C clk
            PIN D drop_pkt
            PIN Q XLXN_17
        END BLOCK
        BEGIN BLOCK XLXI_8 reg9B
            PIN ce XLXN_33
            PIN clk clk
            PIN clr rst
            PIN d(71:0) in_fifo(71:0)
            PIN q(71:0) XLXN_25(71:0)
        END BLOCK
        BEGIN BLOCK XLXI_9 cb8cle
            PIN C clk
            PIN CE XLXN_34(0:0)
            PIN CLR rst
            PIN D(7:0) XLXN_59(7:0)
            PIN L XLXN_17
            PIN CEO
            PIN Q(7:0) waddr(7:0)
            PIN TC
        END BLOCK
        BEGIN BLOCK XLXI_10 cb8ce
            PIN C clk
            PIN CE XLXN_19
            PIN CLR rst
            PIN CEO
            PIN Q(7:0) raddr(7:0)
            PIN TC
        END BLOCK
        BEGIN BLOCK XLXI_11 fdc
            PIN C clk
            PIN CLR rst
            PIN D XLXN_19
            PIN Q valid_data
        END BLOCK
        BEGIN BLOCK XLXI_12 fd8ce
            PIN C clk
            PIN CE XLXN_18
            PIN CLR rst
            PIN D(7:0) waddr(7:0)
            PIN Q(7:0) XLXN_59(7:0)
        END BLOCK
        BEGIN BLOCK XLXI_13 comp8
            PIN A(7:0) waddr(7:0)
            PIN B(7:0) raddr(7:0)
            PIN EQ XLXN_11
        END BLOCK
        BEGIN BLOCK XLXI_14 comp8
            PIN A(7:0) raddr(7:0)
            PIN B(7:0) XLXN_59(7:0)
            PIN EQ XLXN_12
        END BLOCK
        BEGIN BLOCK XLXI_6 fd
            PIN C clk
            PIN D fifowrite
            PIN Q XLXN_34(0:0)
        END BLOCK
        BEGIN BLOCK XLXI_16 or2
            PIN I0 XLXN_15
            PIN I1 XLXN_14
            PIN O XLXN_16
        END BLOCK
        BEGIN BLOCK XLXI_17 and2b1
            PIN I0 XLXN_17
            PIN I1 XLXN_16
            PIN O XLXN_18
        END BLOCK
        BEGIN BLOCK XLXI_18 and3b2
            PIN I0 XLXN_12
            PIN I1 XLXN_11
            PIN I2 fiforead
            PIN O XLXN_19
        END BLOCK
        BEGIN BLOCK XLXI_19 vcc
            PIN P XLXN_33
        END BLOCK
        BEGIN BLOCK XLXI_22 old_dp_72_256k
            PIN addra(7:0) waddr(7:0)
            PIN dina(71:0) XLXN_25(71:0)
            PIN wea XLXN_34(0:0)
            PIN clka clk
            PIN addrb(7:0) raddr(7:0)
            PIN clkb clk
            PIN doutb(71:0) out_fifo(71:0)
        END BLOCK
    END NETLIST
    BEGIN SHEET 1 3520 2720
        INSTANCE XLXI_4 192 592 R0
        INSTANCE XLXI_5 192 944 R0
        INSTANCE XLXI_7 192 2480 R0
        BEGIN INSTANCE XLXI_8 2048 544 R0
        END INSTANCE
        INSTANCE XLXI_9 2064 1408 R0
        INSTANCE XLXI_10 2048 1840 R0
        INSTANCE XLXI_11 2048 2240 R0
        INSTANCE XLXI_12 192 1440 R0
        INSTANCE XLXI_13 992 1776 R0
        INSTANCE XLXI_14 992 2192 R0
        BEGIN BRANCH drop_pkt
            WIRE 128 2224 192 2224
        END BRANCH
        BEGIN BRANCH lastword
            WIRE 112 688 192 688
        END BRANCH
        BEGIN BRANCH firstword
            WIRE 112 336 192 336
        END BRANCH
        BEGIN BRANCH valid_data
            WIRE 2432 1984 2592 1984
        END BRANCH
        BEGIN BRANCH in_fifo(71:0)
            WIRE 1920 512 2048 512
        END BRANCH
        IOMARKER 112 336 firstword R180 28
        IOMARKER 112 688 lastword R180 28
        IOMARKER 128 2224 drop_pkt R180 28
        IOMARKER 128 2352 clk R180 28
        IOMARKER 1920 512 in_fifo(71:0) R180 28
        INSTANCE XLXI_6 896 592 R0
        BEGIN BRANCH fifowrite
            WIRE 864 336 896 336
        END BRANCH
        IOMARKER 864 336 fifowrite R180 28
        IOMARKER 2592 1984 valid_data R0 28
        BEGIN BRANCH rst
            WIRE 80 1088 80 1408
            WIRE 80 1408 192 1408
            WIRE 80 1088 1968 1088
            WIRE 1968 1088 1968 1376
            WIRE 1968 1376 2064 1376
            WIRE 1968 1376 1968 1808
            WIRE 1968 1808 2048 1808
            WIRE 1968 1808 1968 2208
            WIRE 1968 2208 2048 2208
            WIRE 1872 1376 1968 1376
            WIRE 1968 448 2048 448
            WIRE 1968 448 1968 1088
        END BRANCH
        IOMARKER 1872 1376 rst R180 28
        INSTANCE XLXI_16 864 816 R0
        INSTANCE XLXI_17 1248 848 R0
        INSTANCE XLXI_18 1552 1680 R0
        BEGIN BRANCH XLXN_11
            WIRE 1376 1552 1552 1552
        END BRANCH
        BEGIN BRANCH XLXN_12
            WIRE 1376 1968 1456 1968
            WIRE 1456 1616 1456 1968
            WIRE 1456 1616 1552 1616
        END BRANCH
        BEGIN BRANCH fiforead
            WIRE 1344 1264 1536 1264
            WIRE 1536 1264 1552 1264
            WIRE 1552 1264 1552 1488
        END BRANCH
        IOMARKER 1344 1264 fiforead R180 28
        BEGIN BRANCH XLXN_14
            WIRE 576 336 704 336
            WIRE 704 336 704 688
            WIRE 704 688 848 688
            WIRE 848 688 864 688
        END BRANCH
        BEGIN BRANCH XLXN_15
            WIRE 576 688 688 688
            WIRE 688 688 688 752
            WIRE 688 752 864 752
        END BRANCH
        BEGIN BRANCH XLXN_16
            WIRE 1120 720 1248 720
        END BRANCH
        BEGIN BRANCH XLXN_18
            WIRE 112 1072 112 1248
            WIRE 112 1248 192 1248
            WIRE 112 1072 1584 1072
            WIRE 1504 752 1584 752
            WIRE 1584 752 1584 1072
        END BRANCH
        BEGIN BRANCH XLXN_19
            WIRE 1808 1552 1920 1552
            WIRE 1920 1552 1920 1648
            WIRE 1920 1648 2048 1648
            WIRE 1920 1648 1920 1984
            WIRE 1920 1984 2048 1984
        END BRANCH
        BEGIN BRANCH waddr(7:0)
            WIRE 128 912 128 1184
            WIRE 128 1184 192 1184
            WIRE 128 912 800 912
            WIRE 800 912 2592 912
            WIRE 2592 912 2592 1040
            WIRE 2592 1040 2896 1040
            WIRE 800 912 800 1456
            WIRE 800 1456 992 1456
            WIRE 2448 1024 2464 1024
            WIRE 2464 1024 2464 1040
            WIRE 2464 1040 2528 1040
            WIRE 2528 1040 2592 1040
            BEGIN DISPLAY 2528 1040 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH XLXN_25(71:0)
            WIRE 2432 320 2448 320
            WIRE 2448 320 2672 320
            WIRE 2672 320 2672 1072
            WIRE 2672 1072 2896 1072
        END BRANCH
        INSTANCE XLXI_19 1696 256 R0
        BEGIN BRANCH XLXN_33
            WIRE 1760 256 1760 320
            WIRE 1760 320 2048 320
        END BRANCH
        BEGIN BRANCH XLXN_34(0:0)
            WIRE 1280 336 1344 336
            WIRE 1344 336 1344 608
            WIRE 1344 608 1840 608
            WIRE 1840 608 2512 608
            WIRE 2512 608 2512 1152
            WIRE 2512 1152 2736 1152
            WIRE 1840 608 1840 1216
            WIRE 1840 1216 2064 1216
            WIRE 2736 1104 2896 1104
            WIRE 2736 1104 2736 1152
        END BRANCH
        BEGIN BRANCH clk
            WIRE 128 2352 144 2352
            WIRE 144 2352 192 2352
            WIRE 144 256 144 464
            WIRE 144 464 192 464
            WIRE 144 464 144 816
            WIRE 144 816 192 816
            WIRE 144 816 144 976
            WIRE 144 976 144 1312
            WIRE 144 1312 192 1312
            WIRE 144 1312 144 2352
            WIRE 144 976 1648 976
            WIRE 1648 976 1648 1280
            WIRE 1648 1280 2064 1280
            WIRE 1648 976 1664 976
            WIRE 144 256 656 256
            WIRE 656 256 656 464
            WIRE 656 464 896 464
            WIRE 1520 1280 1648 1280
            WIRE 1520 1280 1520 1712
            WIRE 1520 1712 2048 1712
            WIRE 1520 1712 1520 2112
            WIRE 1520 2112 2048 2112
            WIRE 1648 384 2048 384
            WIRE 1648 384 1648 976
            WIRE 1664 896 1664 976
            WIRE 1664 896 2496 896
            WIRE 2496 896 2496 1216
            WIRE 2496 1216 2496 1232
            WIRE 2496 1232 2896 1232
            WIRE 2496 1216 2688 1216
            WIRE 2688 1216 2688 1456
            WIRE 2688 1456 2896 1456
        END BRANCH
        BEGIN INSTANCE XLXI_22 2896 992 R0
        END INSTANCE
        BEGIN BRANCH out_fifo(71:0)
            WIRE 3184 1264 3264 1264
        END BRANCH
        IOMARKER 3264 1264 out_fifo(71:0) R0 28
        BEGIN BRANCH raddr(7:0)
            WIRE 976 1648 992 1648
            WIRE 976 1648 976 1872
            WIRE 976 1872 976 2288
            WIRE 976 2288 2576 2288
            WIRE 976 1872 992 1872
            WIRE 2432 1584 2464 1584
            WIRE 2464 1584 2576 1584
            WIRE 2576 1584 2576 2288
            WIRE 2576 1280 2576 1584
            WIRE 2576 1280 2720 1280
            WIRE 2720 1280 2736 1280
            WIRE 2736 1264 2896 1264
            WIRE 2736 1264 2736 1280
            BEGIN DISPLAY 2464 1584 ATTR Name
                ALIGNMENT SOFT-BCENTER
            END DISPLAY
        END BRANCH
        BEGIN BRANCH XLXN_17
            WIRE 576 2224 912 2224
            WIRE 912 784 1248 784
            WIRE 912 784 912 1152
            WIRE 912 1152 2048 1152
            WIRE 2048 1152 2064 1152
            WIRE 912 1152 912 2032
            WIRE 912 2032 912 2224
        END BRANCH
        BEGIN BRANCH XLXN_59(7:0)
            WIRE 576 1184 624 1184
            WIRE 624 1184 624 1408
            WIRE 624 1408 624 2064
            WIRE 624 2064 992 2064
            WIRE 624 1024 2064 1024
            WIRE 624 1024 624 1184
        END BRANCH
    END SHEET
END SCHEMATIC
