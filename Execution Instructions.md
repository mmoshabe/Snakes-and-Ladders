### Execution Instructions

1. **Connect to SQL Server:**
   - Use your preferred SQL Server management tool (e.g., SQL Server Management Studio, Azure Data Studio, etc.) to connect to your SQL Server instance.

2. **Create Schemas and Tables:**
   - Copy and paste the provided SQL script into a new query window.
   - Execute the script to create the necessary schemas and tables for the Snakes and Ladders game.

3. **Insert Board Configuration Data:**
   - The script includes an `INSERT` statement to populate the `BoardConfiguration` table with predefined board sizes for Beginner, Intermediate, and Advanced levels.

4. **Create Stored Procedures:**
   - The script also includes the creation of three stored procedures:
     - `procs.InitializeSnakesAndLadders`: Initializes the snakes and ladders for a given board and level.
     - `procs.StartNewGame`: Starts a new game with specified players.
     - `procs.PlayTurn`: Simulates a turn for a player in the game.

5. **Initialize Snakes and Ladders:**
   - To set up the snakes and ladders for a specific board, execute the `procs.InitializeSnakesAndLadders` stored procedure.
   - Example:
     EXEC procs.InitializeSnakesAndLadders @BoardID = 1, @Level = 'Beginner';


6. **Start a New Game:**
   - To start a new game with a list of players, execute the `procs.StartNewGame` stored procedure.
   - Example:
     EXEC procs.StartNewGame @BoardID = 1, @PlayerNames = 'Alice,Bob,Charlie';


7. **Simulate Player Turns:**
   - To simulate a turn for a player, execute the `procs.PlayTurn` stored procedure.
   - Example:
     EXEC procs.PlayTurn @GameID = 1, @GamePlayerID = 1;


8. **Review Game History:**
   - The game history, including player moves and dice rolls, is stored in the `GameMove` table. You can query this table to see the progression of the game.
   - Example:
     SELECT * FROM admin.GameMove WHERE GamePlayerID = 1 ORDER BY MoveNumber;
  

