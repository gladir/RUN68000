{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2024
  @website(https://www.gladir.com/run68000)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
}

Program RUN68000;

Const
 MaxLong=MaxLongInt-1;{MaxLong=4398046511103;}
 ResetVector=0;
 A7=15;

  { Valeurs des instructions M68000 }
 _BRA=$60;
 _BSR=$61;
 _BHI=$62;
 _BLS=$63;
 _BCC=$64;
 _BCS=$65;
 _BNE=$66;
 _BEQ=$67;
 _BVC=$68;
 _BVS=$69;
 _BPL=$6A;
 _BMI=$6B;
 _BGE=$6C;
 _BLT=$6D;
 _BGT=$6E;
 _BLE=$6F;

 _MOVE_B=$1000;
 _MOVE_W=$3000;
 _MOVE_L=$2000;
 _PUSH_B=$1F00;
 _PUSH_W=$3F00;
 _PUSH_L=$2F00;
 _MOVEA_L=$2040;
 _MOVEA_W=$3040;
 _MOVEM_L=$48C0;
 _PEA=$4840;
 _LEA=$41C0;
 _LEA_L=$41D0;
 _CMP_B=$B000;
 _CMP_W=$B040;
 _CMP_L=$B080;
 _CMPA_L=$B1C0;
 _CMPA_W=$B0C0;
 _CMPI_W=$0C40;
 _CMPI_L=$0C80;
 _EXT_W=$4880;
 _EXT_L=$48C0;
 _EXTB_L=$49C0;
 _ADD_B=$D000;
 _ADD_W=$D040;
 _ADD_L=$D080;
 _ADDA_W=$D0C0;
 _ADDA_L=$D1C0;
 _SUB_L=$9080;
 _MULS_W=$C1C0;
 _MULS_L=$4C00;
 _DIVS_W=$81C0;
 _DIVS_L=$4C40;
 _NEG_L=$4480;
 _AND_B=$C000;
 _AND_W=$C040;
 _AND_L=$C080;
 _ANDI_B=$0200;
 _ANDI_W=$0240;
 _ANDI_L=$0280;
 _NOT_B=$4600;
 _NOT_W=$4640;
 _NOT_L=$4680;
 _TST_B=$4A00;
 _TST_W=$4A40;
 _TST_L=$4A80;
 _CLR_B=$4200;
 _CLR_W=$4240;
 _CLR_L=$4280;
 _LSL_B=$E108;
 _LSL_W=$E148;
 _LSL_L=$E188;
 _LSR_L=$E088;
 _ASR_W=$E040;
 _ROL_B=$E118;
 _ADDQ_B=$5000;
 _SUBQ_B=$5100;
 _MOVEQ=$7000;
 _SWAP=$4840;
 _EXGDD=$C140;
 _LINK=$4E50;
 _LINK_L=$4808;
 _RTD=$4E74;
 _BTST=$0800;
 _BCLR=$0880;
 _BFCLR=$ECC0;
 _BFEXTS=$EBC0;
 _BFEXTU=$E9C0;
 _BFINS=$EFC0;
 _BFFFO=$EDC0;
 _BFSET=$EEC0;
 _BFTST=$E8C0;
 _BFCHG=$EAC0;
 _JMP_L=$4ED0;
 _JSR_L=$4E90;
 _RTS_L=$4E75;

  { Valeurs des instructions M68881 : }
 _FLOAD=$0000;
 _FSTORE=$2000;
 _FMOVEM=$F200;
 _FADD=$0022;
 _FSUB=$0028;
 _FMUL=$0023;
 _FDIV=$0020;
 _FSMUL=$0027;
 _FSDIV=$0024;
 _FINT=$0001;
 _FINTRZ=$0003;
 _FNEG=$001A;
 _FABS=$0018;
 _FCMP=$0038;
 _FTEST=$003A;
 _FSINH=$0002;
 _FSQRT=$0004;
 _FTANH=$0009;
 _FATAN=$000A;
 _FASIN=$000C;
 _FATANH=$000D;
 _FSIN=$000E;
 _FTAN=$000F;
 _FEXP=$0010;
 _FLN=$0014;
 _FLOG10=$0015;
 _FCOSH=$0019;
 _FACOS=$001C;
 _FCOS=$001D;
 _FSCALE=$0026;

  { Constantes d'instructions SKY : }
 S_FADD=$01;
 S_FSUB=$07;
 S_FMUL=$0B;

Type
 LongRec=Record
  Lo,Hi:Word;
 End;
 Bit=0..1;
{ Byte=0..255;
 Word=0..65535;}
 {LongWord=0..MaxLong;}
 LongWord=LongInt;
 RegNum=0..15; { D0-D7, A0-A7 }

Var
 Mem:Array[0..{MaxLong}40000]of Byte;
 IR:Word;
 PC,EAR,Temp,USP,SSP:LongInt;
 Reg:Array[RegNum]of LongWord;
 T,S,X,N,Z,V,C:Bit;
 PPL:0..7; { Priorit‚ du microprocesseur }

Function ReadMemWord(Address:LongWord):Word;Begin
 If(Address mod 2)<>0 Then Begin
  WriteLn('L''adresse doit ˆtre paire');
  Halt(1);
 End
  Else
 ReadMemWord:=Mem[Address]*256+Mem[Address+1];
End;

Function ReadMemLong(Address:LongWord):LongWord;Begin
 ReadMemLong:=ReadMemWord(Address)*65536+ReadMemWord(Address+2);
End;

Procedure Fetch;Begin
 IR:=ReadMemWord(PC);
 PC:=(PC+2) mod (MaxLong+1);
End;

Procedure Execute;
Type
 BitNum=0..31;
 EAField=0..7;
 EAType=(Src,Dst);
Var
 RegEA:Boolean;

 Function Power2(I:BitNum):LongInt;Begin
  If I=0 Then Power2:=1
         Else Power2:=2*Power2(I-1);
 End;

 Function Bits(From,_To:BitNum;Lw:LongInt):LongInt;Begin
  Bits:=(Lw div Power2(_To)) mod Power2(From-_To);
 End;

 Function SignExtended(W:Word):LongInt;Begin
  If Bits(15,15,W)=0 Then SignExtended:=W
                     Else SignExtended:=$FFFF0000+W;
 End;

 Function ReadLong:LongInt;Begin
  If RegEA Then ReadLong:=Reg[EAR]
           Else ReadLong:=ReadMemLong(EAR);
 End;

 Function ReadWord:Word;Begin
  If RegEA Then ReadWord:=Bits(15,0,REG[EAR])
           Else ReadWord:=ReadMEmWord(EAR);
 End;

 Function ReadByte:Byte;Begin
  If RegEA Then ReadByte:=Bits(7,0,Reg[EAR])
           Else ReadByte:=Mem[EAR];
 End;

 Procedure StoreMemWord(W,EAR:Word);Begin
  If(EAR mod 2)<>0 Then Begin
   WriteLn('L''adresse doit ˆtre paire');
   Halt(1);
  End
   Else
  Begin
   Mem[EAR]:=Bits(15,8,W);
   Mem[EAR+1]:=Bits(7,0,W);
  End;
 End;

 Procedure StoreMemLong(LW,EAR:LongInt);Begin
  StoreMemWord(Bits(31,16,LW),LongRec(EAR).Lo);
  StoreMemWord(Bits(15,0,LW),LongRec(EAR).Hi);
 End;

 Procedure StoreLong(LW:LongInt);Begin
  If RegEA Then Reg[EAR]:=LW
           Else StoreMemLong(LW,EAR);
 End;

 Procedure StoreWord(W:Word);Begin
  If RegEA Then Begin
   If EAR<=7 Then Reg[EAR]:=Bits(31,16,Reg[EAR])*$10000+W
             Else Reg[EAR]:=SignExtended(W);
  End
   Else
  StoreMemWord(W,EAR);
 End;

 Procedure StoreByte(B:Byte);Begin
  If RegEA Then Reg[EAR]:=Bits(31,8,Reg[EAR])*256+B
           Else Reg[EAR]:=B;
 End;

 Procedure PushWord(W:Word);Begin
  Reg[A7]:=Reg[A7]-2;
  EAR:=Reg[A7];
  StoreMemWord(W,Word(EAR));
 End;

 Function PopWord:Word;Begin
  EAR:=Reg[A7];
  Reg[A7]:=Reg[A7]+2;
  PopWord:=ReadWord;
 End;

 Procedure GetEA(SrcDst:EAtype;Mode,EReg:EAfield);Begin
  Case Mode of
   0:Begin
    RegEA:=True;
    EAR:=EReg;
   End;
   1:Begin
    RegEA:=True;
    EAR:=EReg+8;
   End;
   2:Begin
    RegEA:=False;
    EAR:=Reg[EReg+8];
   End;
   5:Begin
    RegEA:=False;
    EAR:=PC;
    PC:=PC+2;
    EAR:=SignExtended(ReadWord)+Reg[EReg+8];
   End;
   3,4,6:Begin
    WriteLn('Non impl‚ment‚');
    Halt(2);
   End;
   7:Case EReg of
    0:Begin
     RegEA:=False;
     EAR:=PC;
     PC:=PC+2;
     EAR:=SignExtended(ReadWord);
    End;
    4:If SrcDst<>Src Then Begin
     WriteLn('Valeur imm‚diate non autoris‚');
     Halt(3);
    End
     Else
    Begin
     RegEA:=False;
     EAR:=PC;
     PC:=PC+2;
    End;
    5:If SrcDst<>Src Then Begin
     WriteLn('Valeur imm‚diate non autoris‚');
     Halt(3);
    End
     Else
    Begin
     RegEA:=False;
     EAR:=PC;
     EAR:=SignExtended(ReadWord)+PC;
     PC:=PC+2;
    End;
    1,2,3,6,7:Begin
     WriteLn('Non impl‚ment‚');
     Halt(2);
    End;
   End;
  End;
 End;

 Procedure SourceEA;Begin
  GetEA(Src,Bits(5,3,IR),Bits(2,0,IR));
 End;

 Procedure DestEA;Begin
  GetEA(Dst,Bits(5,3,IR),Bits(2,0,IR));
 End;

 Procedure MDestEA;Begin
  GetEA(Dst,Bits(8,6,IR),Bits(11,9,IR));
 End;

 Procedure DregEA;Begin
  EAR:=Bits(11,9,IR);
  RegEA:=True;
 End;

 Procedure AregEA;Begin
  EAR:=Bits(11,9,IR)+8;
  RegEA:=True;
 End;

 Procedure Branch;Begin
  If Bits(7,0,IR)=0Then Begin
   WriteLn('Le branchement ne peut pas ˆtre 0');
   Halt(4);
  End
   Else
  If Bits(7,7,IR)=0 Then PC:=(PC+Bits(7,0,IR)) mod MaxLong
                    Else PC:=(PC+Bits(7,0,IR)-256) mod MaxLong;
 End;

 Procedure SetNZVC(LW:LongInt;Len:Integer);Begin
  N:=Ord(LW>=Power2(Len-1));
  Z:=Ord(LW=0);
  V:=0;
  C:=0;
 End;

 Function Add(A,B:LongInt;CY:Bit;Len:Integer):LongInt;
 Var
  Sum,MaxN:LongInt;

  Function Pos(X:LongInt):Boolean;Begin
   Pos:=(X<MaxN);
  End;

  Function Neg(X:LongInt):Boolean;Begin
   Neg:=(X>=MaxN);
  End;

 Begin
  MaxN:=Power2(Len-1);
  Sum:=(A+B+CY) mod (2*MaxN);
  SetNZVC(Sum,Len);
  V:=Ord((Pos(A) and Pos(B) and Neg(Sum))or(Neg(A)and Neg(B) and Pos(Sum)));
  C:=Ord((A+B+CY)>=2*MaxN);
  X:=C;
  Add:=Sum;
 End;

 Function Sub(A,B:LongInt;Borrow:Bit;Len:Integer):LongInt;Begin
  Sub:=Add(A,(2*Power2(N-1)-1-B),(1-Borrow),Len);
  C:=1-C;
  X:=C;
 End;

 Function AndR(A,B:LongInt):LongInt;Begin
  If(A=0)or(B=0)Then AndR:=0
                Else AndR:=2*AndR(A div 2,B div 2)+(A mod 2)+(B mod 2);
 End;

 Function AndD(A,B:LongInt;Len:Integer):LongInt;
 Var
  Rslt:LongInt;
 Begin
  Rslt:=AndR(A,B);
  AndD:=Rslt;
  SetNZVC(Rslt,Power2(Len-1));
 End;

Begin
 Case {Decode}(IR)of
  _MOVE_B:Begin
   SourceEA;
   Temp:=ReadByte;
   MDestEA;
   StoreByte(Temp);
   SetNZVC(Temp,8);
  End;
  _MOVE_W:Begin
   SourceEA;
   Temp:=ReadWord;
   MDestEA;
   StoreWord(Temp);
   SetNZVC(Temp,16);
  End;
  _MOVE_L:Begin
   SourceEA;
   Temp:=ReadLong;
   MDestEA;
   StoreLong(Temp);
   SetNZVC(Temp,32);
  End;
  _MOVEA_W:Begin
   SourceEA;
   Temp:=ReadWord;
   AregEA;
   StoreWord(Temp);
  End;
  _MOVEA_L:Begin
   SourceEA;
   Temp:=ReadLong;
   AregEA;
   StoreLong(Temp);
  End;
  _LEA_L:Begin
   SourceEA;
   Temp:=EAR;
   AregEA;
   StoreLong(Temp);
  End;
  _ADD_B:Begin
   SourceEA;
   Temp:=ReadByte;
   DregEA;
   StoreByte(Add(ReadByte,Temp,0,8));
  End;
  _ADD_W:Begin
   SourceEA;
   Temp:=ReadWord;
   DregEA;
   StoreWord(Add(ReadWord,Temp,0,16));
  End;
  _ADD_L:Begin
   SourceEA;
   Temp:=ReadLong;
   DregEA;
   StoreLong(Add(ReadLong,Temp,0,32));
  End;
  _ADDA_W:Begin
   SourceEA;
   Temp:=ReadWord;
   AregEA;
   StoreWord((ReadWord+Temp) mod $10000);
  End;
  _ADDA_L:Begin
   SourceEA;
   Temp:=ReadLong;
   AregEA;
   StoreLong((ReadLong+Temp) mod $10000);
  End;
  _AND_B:Begin
   SourceEA;
   Temp:=ReadByte;
   DregEA;
   StoreByte(AndD(ReadByte,Temp,8));
  End;
  _AND_W:Begin
   SourceEA;
   Temp:=ReadWord;
   DRegEA;
   StoreWord(AndD(ReadWord,Temp,16));
  End;
  _AND_L:Begin
   SourceEA;
   Temp:=ReadLong;
   DRegEA;
   StoreLong(AndD(ReadLong,Temp,32));
  End;
  _CMP_B:Begin
   SourceEA;
   Temp:=ReadByte;
   DRegEA;
   Temp:=Sub(ReadByte,Temp,0,8);
  End;
  _CMP_W:Begin
   SourceEA;
   Temp:=ReadWord;
   DRegEA;
   Temp:=Sub(ReadWord,Temp,0,16);
  End;
  _CMP_L:Begin
   SourceEA;
   Temp:=ReadLong;
   DregEA;
   Temp:=Sub(ReadLong,Temp,0,32);
  End;
  _CMPA_W:Begin
   SourceEA;
   Temp:=ReadWord;
   ARegEA;
   Temp:=Sub(ReadWord,Temp,0,16);
  End;
  _CMPA_L:Begin
   SourceEA;
   Temp:=ReadLong;
   ARegEA;
   Temp:=Sub(ReadLong,Temp,0,32);
  End;
  _CLR_B:Begin
   DestEA;
   StoreByte(0);
   SetNZVC(0,8);
  End;
  _CLR_W:Begin
   DestEA;
   StoreWord(0);
   SetNZVC(0,16);
  End;
  _CLR_L:Begin
   DestEA;
   StoreLong(0);
   SetNZVC(0,32);
  End;
  _NOT_B:Begin
   DestEA;
   Temp:=ReadByte;
   StoreByte(Sub($FF,Temp,0,8));
  End;
  _NOT_W:Begin
   DestEA;
   Temp:=ReadWord;
   StoreByte(Sub($FFFF,Temp,0,16));
  End;
  _BNE:If Z=0 Then Branch;
  _BEQ:If Z=1 Then Branch;
  _JMP_L:Begin
   DestEA;
   If RegEA Then Begin
    WriteLn('Erreur de saut');
    Halt(4);
   End;
   PC:=EAR;
  End;
  _JSR_L:Begin
   DestEA;
   If RegEA Then Begin
    WriteLn('Erreur de saut');
    Halt(4);
   End;
   Temp:=EAR;
   PushWord(Bits(15,0,PC));
   PushWord(Bits(31,16,PC));
   PC:=Temp;
  End;
  _RTS_L:PC:=$10000*PopWord+PopWord;
 End;
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('RUN68000 : Cette commande permet d''ex‚cuter du code machine de microprocesseur 68000.');
  WriteLn;
  WriteLn('Syntaxe : RUN68000 [option]');
  WriteLn;
 End
  Else
 Begin
  SSP:=ReadMemLong(ResetVector);
  PC:=ReadMemLong(ResetVector+4);
  S:=1; PPL:=7;
  Reg[A7]:=SSP;
  While True Do Begin
   Fetch;
   Execute;
  End;
 End;
END.