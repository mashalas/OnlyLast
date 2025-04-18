program OnlyLast;

uses
  SysUtils,
  crt;

const
  SEQUENTIAL_NEED_COUNT = 3;
  FOUND__INITIAL_SIZE = 1024;
type
  TFoundRec = record
    filename: string;
    filetime: TDateTime;
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


Procedure help();
Begin
  writeln('OnlyLast [-v|--verbose] [-i|--invert] [-d|--dry-run] DirName Mask KeepCount');
  writeln('In directory "DirName" for files matched with "Mask" keep only "KeepCount" last ones.');
  writeln('  -v|--verbose   verbose mode');
  writeln('  -i|--invert    keep earliest files instead of last');
  writeln('  -d|--dry-run   do not delete files, only notuft which ones will be deleted');
End;

//-------------------------------Сортировать список найденных файлов по дате--------------------
Procedure SortFound(FoundCount: LongWord; var Found: array of TFoundRec; ascending: boolean = true);
var
  i, j: LongWord;
  tmp: TFoundRec;
  NeedToSwap: boolean;
Begin
  for i:=0 to FoundCount-2 do
    for j:=i+1 to FoundCount-1 do
      begin
        if (ascending) and (Found[j].filetime < Found[i].filetime) then
          NeedToSwap := true;
        if (not ascending) and (Found[j].filetime > Found[i].filetime) then
          NeedToSwap := true;
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
Begin
  for i := 0 to FoundCount-1 do
    begin
      write(NumerateSince+i);
      write(')');
      write('  [' + DateTimeToStr(Found[i].filetime) + ']');
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

Procedure OnlyLast(DirName: string; Mask: string; KeepCount: LongWord; Verbose: boolean; Invert: boolean; DryRun: boolean);
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
      writeln('For ' + PathForSearch + ' keep only ' + IntToStr(KeepCount) + ' last files.');
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
        Found[FoundCount].NeedToDelete := false;
        Inc(FoundCount);
      until FindNext(SR) <> 0;
    end
  else
    begin
      writeln('No files matched');
      exit;
    end;

  SortFound(FoundCount, Found, not Invert);
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
  for i:=1 to ParamCount do
    begin
      if (ParamStr(i) = '-h') or (ParamStr(i) = '--help') or (ParamStr(i) = '-help') or (ParamStr(i) = '/?') then
        begin
          PrintHelpAndExit := true;
          break;
        end;
      if (ParamStr(i) = '-v') or (ParamStr(i) = '--verbose') then
        begin
          Verbose := true;
          continue;
        end;
      if (ParamStr(i) = '-i') or (ParamStr(i) = '--invert') then
        begin
          Invert := true;
          continue;
        end;
      if (ParamStr(i) = '-d') or (ParamStr(i) = '--dry-run') then
        begin
          DryRun := true;
          continue;
        end;
      if SequentialCount < SEQUENTIAL_NEED_COUNT then
        begin
          //необходимое количество параметров ещё не получено
          Inc(SequentialCount);
          Sequential[SequentialCount] := ParamStr(i);
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
      halt(1);
    end;
  
  writeln(Sequential[1], ' ', Sequential[2], ' ', KeepCount, ' ', Verbose, ' ', Invert, ' ', DryRun);

  KeepCount := StrToInt(Sequential[3]);
  OnlyLast(Sequential[1], Sequential[2], KeepCount, Verbose, Invert, DryRun);
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
