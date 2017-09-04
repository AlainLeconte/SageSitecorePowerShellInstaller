USE Master
GO
DECLARE @name VARCHAR(128)
DECLARE @szSQL VARCHAR(128)
DECLARE db_cursor CURSOR
FOR
    SELECT  name
    FROM    master.dbo.sysdatabases
    WHERE   name NOT IN ( 'master', 'model', 'msdb', 'tempdb' )  -- exclude these databases
            AND name LIKE 'Unity80_r4_%'
 
OPEN db_cursor   
FETCH NEXT FROM db_cursor INTO @name   
WHILE @@FETCH_STATUS = 0 
    BEGIN   
		SET @szSQL = 'ALTER DATABASE ' + @name +' SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
        EXECUTE(@szSQL)
        SET @szSQL = 'DROP DATABASE ' + @name 
        EXECUTE(@szSQL)
        FETCH NEXT FROM db_cursor INTO @name   
    END   
CLOSE db_cursor   
DEALLOCATE db_cursor
