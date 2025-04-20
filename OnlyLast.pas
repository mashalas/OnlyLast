program OnlyLast;

uses
  SysUtils,
  crt;

const
  SEQUENTIAL_NEED_COUNT  = 3;
  FOUND__INITIAL_SIZE:LongWord = 1024;
  SORT_BY__TIME:word = 1;
  SORT_BY__SIZE:word = 2;
  SORT_BY__NAME:word = 3;

  ERR__WRONG_REQUIRED_ARGUMENTS_COUNT:word = 1;
  ERR__WRONG_SORT_BY:word = 2;

type
  TFoundRec = record
    filename: string;
    filetime: TDateTime;
    filesize: Int64;
    NeedToDelete: boolean;
  end;

var
  PrintHelpAndExit: boolean;
  Verbose: boolean;
  Invert: boolean;
  DryRun: boolean;
  KeepCount: LongWord;
  i: word;
  SequentialCount: word;
  Sequential: array[1..SEQUENTIAL_NEED_COUNT] of string;
  key, value: string;
  SortBy: word;
  ParamValue: string;


Procedure help();
Begin
  writeln('NAME');
  writeln('        OnlyLast - keep in a directory only <N> files matched with the mask');
  writeln('');
  writeln('SYNOPSIS');
  writeln('        OnlyLast [OPTIONS]... DirName Mask KeepCount');
  writeln('');
  writeln('OPTIONS');
  writeln('        -h|--help');
  writeln('               print this help and exit');
  writeln('');
  writeln('        -v|--verbose');
  writeln('               verbose mode');
  writeln('');
  writeln('        -i|--invert');
  writeln('               keep earliest files instead of last');
  writeln('');
  writeln('        -d|--dry-run');
  writeln('               do not delete files, only notify which ones will be deleted');
  writeln('');
  writeln('        -s|--sort-by time|size|name');
  writeln('               sorting criteria besides the time, time - is default value');
  writeln('');
  writeln('POSITIONAL ARGUMENTS');
  writeln('        DirName');
  writeln('               directory where to keep only last files');
  writeln('');
  writeln('        Mask');
  writeln('               mask for selecting files. Symbols "*" and "?" allowed.');
  writeln('');
  writeln('        KeepCount');
  writeln('               how many matched files keep in the directory');
  writeln('');
  writeln('URL');
  writeln('        https://github.com/mashalas/OnlyLast');
  writeln('');
  writeln('LICENSE');
  writeln('        GPV-3.0');
End;

//--------------------------Дополнить строку до необходимой длины-----------------------------
Function SetStringLength(s: string; TargetLength: word; add: string; AddBefore: boolean): string;
Begin
  while Length(s) < TargetLength do
    begin
      if AddBefore then
        s := add + s
      else
        s := s + add;
    end;
  exit(s);
End;

//---------------------Начинается ли строка с заданной последовательности-----------------------
Function StringStartsWith(s:string; part: string): boolean;
Begin
  if Length(s) >= Length(part) then
    begin
      if copy(s, 1, Length(part)) = part then
        exit(true);
    end;
  exit(false);
End;

//------Разделить --key-name=value for key на [key-name] & [value for key] -------------
Procedure ParseOption(RawOption: string; var key: string; var value: string);
const
  STATE__REDING_PREFIX: word = 1;
  STATE__READING_KEY:   word = 2;
  STATE__READING_VALUE: word = 3;
var
  i: integer;
  state: word;
Begin
  key := '';
  value := '';
  state := STATE__REDING_PREFIX;
  for i:=1 to Length(RawOption) do
    begin
      if state = STATE__REDING_PREFIX then
        begin
          if RawOption[i] = '-' then
            continue; //минусы перед именем параметра
          state := STATE__READING_KEY;
          //key := RawOption[i];
          //continue;
        end;
      if state = STATE__READING_KEY then
        begin
          if RawOption[i] = '=' then
            begin
              state := STATE__READING_VALUE;
              continue;
            end;
          key := key + RawOption[i];
        end;
      if state = STATE__READING_VALUE then
        value := value + RawOption[i];
    end;
End;

//-------------------------------Сортировать список найденных файлов по дате--------------------
Procedure SortFound(FoundCount: LongWord; var Found: array of TFoundRec; SortBy: word; ascending: boolean = true);
var
  i, j: LongWord;
  tmp: TFoundRec;
  NeedToSwap: boolean;
Begin
  for i:=0 to FoundCount-2 do
    for j:=i+1 to FoundCount-1 do
      begin
        NeedToSwap := false;
        if SortBy = SORT_BY__TIME then
          begin
            if (ascending) and (Found[j].filetime < Found[i].filetime) then
              NeedToSwap := true;
            if (not ascending) and (Found[j].filetime > Found[i].filetime) then
              NeedToSwap := true;
          end;
        if SortBy = SORT_BY__SIZE then
          begin
            if (ascending) and (Found[j].filesize < Found[i].filesize) then
              NeedToSwap := true;
            if (not ascending) and (Found[j].filesize > Found[i].filesize) then
              NeedToSwap := true;
          end;
        if SortBy = SORT_BY__NAME then
          begin
            if (ascending) and (Found[j].filename < Found[i].filename) then
              NeedToSwap := true;
            if (not ascending) and (Found[j].filename > Found[i].filename) then
              NeedToSwap := true;
          end;
        if NeedToSwap then
          begin
            //надо переставить местами
            tmp := Found[i];
            Found[i] := Found[j];
            Found[j] := tmp;
          end;
      end;
End;

//----------------------------------Вывести список найденных файлов-----------------------------
Procedure ListFound(FoundCount: LongWord; Found: array of TFoundRec; NumerateSince: LongWord = 1);
var
  i: LongWord;
  SizeStr: string;
  MaxSize: Int64;
  MaxSizeStr: string;
  MaxSizeStrLen: integer;
Begin
  //определить максимальный размер выбранных файлов, чтобы строку с размером файла дополнять до этого же количества символов
  MaxSize := Found[0].filesize;
  for i := 1 to FoundCount-1 do
    if Found[i].filesize > MaxSize then
      MaxSize := Found[i].filesize;
  MaxSizeStr := IntToStr(MaxSize);
  MaxSizeStrLen := Length(MaxSizeStr);

  for i := 0 to FoundCount-1 do
    begin
      write(NumerateSince+i);
      write(')');
      write(' [' + DateTimeToStr(Found[i].filetime) + ']');
      
      SizeStr := IntToStr(Found[i].filesize);
      SizeStr := SetStringLength(SizeStr, MaxSizeStrLen, ' ', true);
      write(' ' + SizeStr);

      write('  ' + Found[i].filename);
      if Found[i].NeedToDelete then
        write('  delete')
      else
        write('  keep');
      writeln('');
    end;
End;

//------------------------------------Отметить какие файлы удалить-------------------------------
Procedure MarkForDelete(FoundCount: LongWord; var Found: array of TFoundRec; KeepCount: LongWord);
var
  i: LongWord;
  KeepSince: LongWord;
Begin
  if KeepCount < FoundCount then
    begin
      //сохранить надо не все из найденных
      // 0 1 2 3 4 5 6 7 8 9  {10}
      // d d d k k k k k k k  KeepCount=7
      KeepSince := FoundCount - KeepCount;
      for i := 0 to KeepSince-1 do
        Found[i].NeedToDelete := true;
    end;
End;

//--------------------------------------Выполнить удаление отмеченных файлов-------------------------------
Procedure DoDeleting(DirName: string; FoundCount: LongWord; Found: array of TFoundRec; Verbose: boolean; DryRun: boolean);
var
  i: LongWord;
  path: string;
Begin
  for i := 0 to FoundCount do
    if Found[i].NeedToDelete then
      begin
        path := DirName + DirectorySeparator + Found[i].filename;
        if (Verbose) or (DryRun) then
          writeln('delete: ' + path);
        if not DryRun then
          DeleteFile(path);
      end
    else
      break; //если встретился сохраняемый файл, все последующие файлы тоже остаются (закончился список удаляемых)
End;

Function _CheckOption(name: string; var ActiveParamIndex: word; var value: string; IsFlag: boolean = false): boolean;
var
  a: string;
Begin
  //if name = '' then
  //  exit(false);
  a := ParamStr(ActiveParamIndex);
  if IsFlag then
    begin
      if a = name then
        exit(true);
      exit(false);
    end;
  //проверяемый аргумент командной строки не является логическим флагом, значит должен содержать значение
  //-k value
  //-k=value
  //--key=value
  if a = name then
    begin
      if ActiveParamIndex >= ParamCount then
        exit(false); //больше нет аргументов, где бы можно было взять значение
      //-k value    --key value
      Inc(ActiveParamIndex);
      value := ParamStr(ActiveParamIndex);
      exit(true);
    end;
  if (Length(a) >= Length(name)+2) and (a[Length(name)+1] = '=') then
    begin
      //--key=value
      //12345678901 {11}
      //-k=v  {4}
      value := copy(a, Length(name)+2, Length(a)-Length(name)-1);
      //writeln(' compare ' + a + ' with ' + name + '|' + a + '|' + value + ']');
      exit(true);
    end;
  exit(false);
End;

Function CheckOption(ShortName: string; LongName: string; var ActiveParamIndex: word; var value: string; IsFlag: boolean = false): boolean;
var
  matched: boolean;
Begin
  matched := false;
  value := '';
  if ShortName <> '' then
    begin
      matched := _CheckOption(ShortName, ActiveParamIndex, value, IsFlag);
      if matched then
        exit(true);
    end;
  if LongName <> '' then
    begin
      matched := _CheckOption(LongName, ActiveParamIndex, value, IsFlag);
      if matched then
        exit(true);
    end;
  exit(false);
End;

Procedure OnlyLast(DirName: string; Mask: string; KeepCount: LongWord; Verbose: boolean; Invert: boolean; DryRun: boolean; SortBy: word);
var
  SR: TSearchRec;
  FoundCount: LongWord;
  Found: array of TFoundRec;
  FoundReservedSize: LongWord;
  PathForSearch: string; 
Begin
  PathForSearch := DirName + DirectorySeparator + Mask;
  if Verbose then
    begin
      write('For ' + PathForSearch + ' keep only ' + IntToStr(KeepCount) + ' last files sorted by ');
      if SortBy = SORT_BY__TIME then
        write('time')
      else if SortBy = SORT_BY__SIZE then
        write('size')
      else if SortBy = SORT_BY__NAME then
        write('name');
      writeln('.');
    end;
  FoundCount := 0;
  FoundReservedSize := FOUND__INITIAL_SIZE;
  SetLength(Found, FoundReservedSize);
  if FindFirst(PathForSearch, faAnyFile, SR) = 0 then
    begin
      repeat
        if SR.attr and faDirectory = faDirectory then
          continue; //пропустить каталоги
        //writeln(SR.name:40, SR.size:15);
        if FoundCount = FoundReservedSize then
          begin
            //увеличить память под список найденных элементов
            FoundReservedSize := FoundReservedSize * 2;
            SetLength(Found, FoundReservedSize);
          end;
        Found[FoundCount].filename := SR.name;
        Found[FoundCount].filetime := SR.TimeStamp;
        Found[FoundCount].filesize := SR.size;
        Found[FoundCount].NeedToDelete := false;
        Inc(FoundCount);
      until FindNext(SR) <> 0;
    end
  else
    begin
      writeln('No files matched');
      exit;
    end;

  SortFound(FoundCount, Found, SortBy, not Invert);
  MarkForDelete(FoundCount, Found, KeepCount);
  if Verbose then
    ListFound(FoundCount, Found, 1);
  DoDeleting(DirName, FoundCount, Found, Verbose, DryRun);
End;

BEGIN
  PrintHelpAndExit := false;
  Verbose := false;
  Invert := false;
  DryRun := false;
  SequentialCount := 0;
  SortBy := SORT_BY__TIME;

  i := 0;
  while i < ParamCount do
    begin
      Inc(i);
      //writeln(i, ' : ', ParamStr(i));
      if CheckOption('-h', '--help', i, ParamValue, true) then
        PrintHelpAndExit := true
      else if CheckOption('/?', '-help', i, ParamValue, true) then
        PrintHelpAndExit := true
      else if CheckOption('-v', '--verbose', i, ParamValue, true) then
        Verbose := true
      else if CheckOption('-i', '--invert', i, ParamValue, true) then
        Invert := true
      else if CheckOption('-d', '--dry-run', i, ParamValue, true) then
        DryRun := true
      else if CheckOption('', '--sort-by', i, ParamValue) then
        begin
          case ParamValue of
            'name': SortBy := SORT_BY__NAME;
            'time': SortBy := SORT_BY__TIME;
            'size': SortBy := SORT_BY__SIZE
          else
            writeln('ERROR!!! Wrong value for "sort-by"');
            help();
            halt(ERR__WRONG_SORT_BY);
          end;
          continue;
        end
      else
        begin
          if SequentialCount < SEQUENTIAL_NEED_COUNT then
            begin
              //необходимое количество параметров ещё не получено
              Inc(SequentialCount);
              Sequential[SequentialCount] := ParamStr(i);
            end;
        end;
    end;

  if PrintHelpAndExit then
    begin
      help();
      halt(0);
    end;

  if SequentialCount < SEQUENTIAL_NEED_COUNT then
    begin
      writeln('ERROR!!! Not enought parameters');
      help();
      halt(ERR__WRONG_REQUIRED_ARGUMENTS_COUNT);
    end;
  
  KeepCount := StrToInt(Sequential[3]);
  //writeln(Sequential[1], ' ', Sequential[2], ' ', Sequential[3]);
  //writeln(KeepCount, ' ', Verbose, ' ', Invert, ' ', DryRun, ' ', SortBy);

  OnlyLast(Sequential[1], Sequential[2], KeepCount, Verbose, Invert, DryRun, SortBy);
END.

{
type TRawbyteSearchRec = record
public
  Time: LongInt;	// Last modification timestamp
  Size: Int64;		//File size in bytes
  Attr: LongInt;	//File attributes
  Name: RawByteString;	//File name (single byte version)
  ExcludeAttr: LongInt;	//For internal use only
  FindHandle: THandle;	//Native file search handle. For internal use only, treat as opaque
  property TimeStamp: TDateTime; [r]
end;
}
