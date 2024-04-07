DECLARE @tablename varchar(80),@shemaname varchar(80)
DECLARE @SQL AS NVARCHAR(200)
DECLARE TblName_cursor CURSOR FOR
SELECT t.[name],s.[name] 
FROM sys.tables t 
	JOIN sys.schemas s
	ON s.schema_id = t.schema_id
WHERE t.[name] NOT LIKE '%joinmodel%'

OPEN TblName_cursor

FETCH NEXT FROM TblName_cursor
INTO @tablename,@shemaname

WHILE @@FETCH_STATUS = 0
BEGIN
SET @SQL = 'UPDATE STATISTICS [' + @shemaname+'].[' + @TableName + '] WITH FULLSCAN '

exec sp_executesql @SQL  
PRINT @SQL

   FETCH NEXT FROM TblName_cursor
   INTO @tablename,@shemaname
END

CLOSE TblName_cursor
DEALLOCATE TblName_cursor