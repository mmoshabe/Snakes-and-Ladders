
-- Drop and recreate schemas
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'admin') DROP SCHEMA admin;
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'config') DROP SCHEMA config;
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'procs') DROP SCHEMA procs;

exec ('CREATE SCHEMA admin');
exec ('CREATE SCHEMA config');
exec ('CREATE SCHEMA procs');

-- Drop and recreate tables in the admin schema
IF OBJECT_ID('admin.BoardConfiguration', 'U') IS NOT NULL DROP TABLE admin.BoardConfiguration;
IF OBJECT_ID('admin.Player', 'U') IS NOT NULL DROP TABLE admin.Player;
IF OBJECT_ID('admin.Game', 'U') IS NOT NULL DROP TABLE admin.Game;
IF OBJECT_ID('admin.GamePlayer', 'U') IS NOT NULL DROP TABLE admin.GamePlayer;
IF OBJECT_ID('admin.GameMove', 'U') IS NOT NULL DROP TABLE admin.GameMove;

CREATE TABLE admin.BoardConfiguration (
    BoardID INT IDENTITY PRIMARY KEY,
    Level VARCHAR(50) NOT NULL,
    Rows INT NOT NULL,
    Columns INT NOT NULL
);

CREATE TABLE admin.Player (
    PlayerID INT IDENTITY PRIMARY KEY,
    PlayerName VARCHAR(50) NOT NULL
);

CREATE TABLE admin.Game (
    GameID INT IDENTITY PRIMARY KEY,
    BoardID INT NOT NULL,
    StartTime DATETIME NOT NULL DEFAULT GETDATE(),
    EndTime DATETIME,
    FOREIGN KEY (BoardID) REFERENCES admin.BoardConfiguration(BoardID)
);

CREATE TABLE admin.GamePlayer (
    GamePlayerID INT IDENTITY PRIMARY KEY,
    GameID INT NOT NULL,
    PlayerID INT NOT NULL,
    FOREIGN KEY (GameID) REFERENCES admin.Game(GameID),
    FOREIGN KEY (PlayerID) REFERENCES admin.Player(PlayerID)
);

CREATE TABLE admin.GameMove (
    MoveID INT IDENTITY PRIMARY KEY,
    GamePlayerID INT NOT NULL,
    MoveNumber INT NOT NULL,
    DiceRoll INT NOT NULL,
    StartPosition INT NOT NULL,
    EndPosition INT NOT NULL,
    MoveType VARCHAR(50) NOT NULL,
    FOREIGN KEY (GamePlayerID) REFERENCES admin.GamePlayer(GamePlayerID)
);

-- Drop and recreate tables in the config schema
IF OBJECT_ID('config.SnakesAndLaddersConfiguration', 'U') IS NOT NULL DROP TABLE config.SnakesAndLaddersConfiguration;

CREATE TABLE config.SnakesAndLaddersConfiguration (
    ConfigurationID INT IDENTITY PRIMARY KEY,
    BoardID INT NOT NULL,
    Type VARCHAR(50) NOT NULL,
    StartPosition INT NOT NULL,
    EndPosition INT NOT NULL,
    FOREIGN KEY (BoardID) REFERENCES admin.BoardConfiguration(BoardID)
);

-- Insert board configuration data
INSERT INTO admin.BoardConfiguration (Level, Rows, Columns) VALUES
('Beginner', 25, 25),
('Intermediate', 50, 50),
('Advanced', 100, 100);

-- Drop and recreate stored procedures in the procs schema
IF OBJECT_ID('procs.InitializeSnakesAndLadders', 'P') IS NOT NULL DROP PROCEDURE procs.InitializeSnakesAndLadders;
IF OBJECT_ID('procs.StartNewGame', 'P') IS NOT NULL DROP PROCEDURE procs.StartNewGame;
IF OBJECT_ID('procs.PlayTurn', 'P') IS NOT NULL DROP PROCEDURE procs.PlayTurn;

CREATE PROCEDURE procs.InitializeSnakesAndLadders
    @BoardID INT,
    @Level VARCHAR(50)
AS
BEGIN
    DECLARE @StartPosition INT, @EndPosition INT;
    DECLARE @Counter INT = 0;
    DECLARE @MaxPosition INT;
    DECLARE @NumberOfSnakes INT;
    DECLARE @NumberOfLadders INT;
    DECLARE @Rows INT, @Columns INT;

    -- Determine the maximum position on the board and row size
    SELECT @Rows = Rows, @Columns = Columns FROM admin.BoardConfiguration WHERE BoardID = @BoardID;
    SET @MaxPosition = @Rows * @Columns;

    -- Determine the number of snakes and ladders based on the level
    IF @Level = 'Beginner'
    BEGIN
        SET @NumberOfSnakes = 3;
        SET @NumberOfLadders = 3;
    END
    ELSE IF @Level = 'Intermediate'
    BEGIN
        SET @NumberOfSnakes = 4;
        SET @NumberOfLadders = 4;
    END
    ELSE IF @Level = 'Advanced'
    BEGIN
        SET @NumberOfSnakes = 5;
        SET @NumberOfLadders = 5;
    END

    -- Add snakes
    WHILE @Counter < @NumberOfSnakes
    BEGIN
        SET @StartPosition = FLOOR(RAND() * (@MaxPosition - 2 * @Columns)) + 2 * @Columns; -- Ensure start position is not the first or last row
        SET @EndPosition = FLOOR(RAND() * (@StartPosition - 2 * @Columns)) + @Columns; -- Ensure end position is at least one row below

        IF @StartPosition > @EndPosition AND @StartPosition < @MaxPosition AND @EndPosition > @Columns
        BEGIN
            INSERT INTO config.SnakesAndLaddersConfiguration (BoardID, Type, StartPosition, EndPosition)
            VALUES (@BoardID, 'Snake', @StartPosition, @EndPosition);

            SET @Counter = @Counter + 1;
        END
    END

    SET @Counter = 0;

    -- Add ladders
    WHILE @Counter < @NumberOfLadders
    BEGIN
        SET @StartPosition = FLOOR(RAND() * (@MaxPosition - 2 * @Columns)) + 1; -- Ensure start position is not the first or last row
        SET @EndPosition = @StartPosition + FLOOR(RAND() * (@MaxPosition - @StartPosition - @Columns)) + @Columns; -- Ensure end position is at least one row above

        IF @EndPosition > @StartPosition AND @StartPosition > 0 AND @EndPosition < @MaxPosition
        BEGIN
            INSERT INTO config.SnakesAndLaddersConfiguration (BoardID, Type, StartPosition, EndPosition)
            VALUES (@BoardID, 'Ladder', @StartPosition, @EndPosition);

            SET @Counter = @Counter + 1;
        END
    END
END;
GO

CREATE PROCEDURE [procs].[StartNewGame]
    @BoardID INT,
    @PlayerNames VARCHAR(MAX)
AS
BEGIN
    DECLARE @GameID INT;
    DECLARE @PlayerName VARCHAR(50);
    DECLARE @PlayerID INT;
    DECLARE @GamePlayerID INT;

    -- Start a new game
    INSERT INTO admin.Game (BoardID, StartTime)
    VALUES (@BoardID, GETDATE());
    SET @GameID = SCOPE_IDENTITY();

    -- Split player names and add them to the game
    DECLARE @PlayerNamesTable TABLE (PlayerName VARCHAR(50));
    INSERT INTO @PlayerNamesTable SELECT value FROM STRING_SPLIT(@PlayerNames, ',');

    DECLARE player_cursor CURSOR FOR SELECT PlayerName FROM @PlayerNamesTable;
    OPEN player_cursor;

    FETCH NEXT FROM player_cursor INTO @PlayerName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Add player if not exists
        IF NOT EXISTS (SELECT 1 FROM admin.Player WHERE PlayerName = @PlayerName)
        BEGIN
            INSERT INTO admin.Player (PlayerName)
            VALUES (@PlayerName);
            SET @PlayerID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            SELECT @PlayerID = PlayerID FROM admin.Player WHERE PlayerName = @PlayerName;
        END

        -- Add player to the game
        INSERT INTO admin.GamePlayer (GameID, PlayerID)
        VALUES (@GameID, @PlayerID);
        SET @GamePlayerID = SCOPE_IDENTITY();

        -- Add initial move for player
        INSERT INTO admin.GameMove (GamePlayerID, MoveNumber, DiceRoll, StartPosition, EndPosition, MoveType)
        VALUES (@GamePlayerID, 1, 0, 1, 1, 'Start');

        FETCH NEXT FROM player_cursor INTO @PlayerName;
    END

    CLOSE player_cursor;
    DEALLOCATE player_cursor;
END;
GO

-- Procedure to simulate a single turn for a player
CREATE PROCEDURE [procs].[PlayTurn]
    @GameID INT,
    @GamePlayerID INT
AS
BEGIN
    DECLARE @CurrentPosition INT;
    DECLARE @DiceRoll INT;
    DECLARE @NewPosition INT;
    DECLARE @FinalPosition INT;
    DECLARE @MoveType VARCHAR(50);

    -- Get the current position of the player
    SELECT TOP 1 @CurrentPosition = EndPosition 
    FROM admin.GameMove 
    WHERE GamePlayerID = @GamePlayerID 
    ORDER BY MoveNumber DESC;

    -- Roll the dice
    SET @DiceRoll = FLOOR(RAND() * 6) + 1;

    -- Calculate the new position
    SET @NewPosition = @CurrentPosition + @DiceRoll;

    -- Check if the new position overshoots 100 and reflect back
    IF @NewPosition > 100
    BEGIN
        SET @NewPosition = 100 - (@NewPosition - 100);
    END

    -- Set the initial move type
    SET @MoveType = 'Forward move';

    -- Check for ladders
    SELECT @FinalPosition = EndPosition 
    FROM config.SnakesAndLaddersConfiguration 
    WHERE BoardID = (SELECT BoardID FROM admin.Game WHERE GameID = @GameID) 
    AND StartPosition = @NewPosition 
    AND Type = 'Ladder';

    IF @FinalPosition IS NOT NULL
    BEGIN
        SET @MoveType = 'Ladder Climb';
    END
    ELSE
    BEGIN
        -- Check for snakes
        SELECT @FinalPosition = EndPosition 
        FROM config.SnakesAndLaddersConfiguration 
        WHERE BoardID = (SELECT BoardID FROM admin.Game WHERE GameID = @GameID) 
        AND StartPosition = @NewPosition 
        AND Type = 'Snake';

        IF @FinalPosition IS NOT NULL
        BEGIN
            SET @MoveType = 'Snake Bite Drop';
        END
        ELSE
        BEGIN
            SET @FinalPosition = @NewPosition;
        END
    END

    -- Record the move
    INSERT INTO admin.GameMove (GamePlayerID, MoveNumber, DiceRoll, StartPosition, EndPosition, MoveType)
    VALUES (@GamePlayerID, 
            (SELECT ISNULL(MAX(MoveNumber), 0) + 1 FROM admin.GameMove WHERE GamePlayerID = @GamePlayerID), 
            @DiceRoll, @CurrentPosition, @FinalPosition, @MoveType);

    -- Check if the game is won
    IF @FinalPosition = 100
    BEGIN
        -- Update game end time
        UPDATE admin.Game
        SET EndTime = GETDATE()
        WHERE GameID = @GameID;
    END
END;
GO
