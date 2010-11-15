{-# LANGUAGE ParallelListComp #-}

import Sim.MainArgs
import Sim.Draw
import Sim.Config
import Common.Dump
import Common.World
import Common.Body
import Common.Util
import Solver
import Timing
import Points2D.Generate
import Graphics.Gloss
import System.Environment
import System.Console.ParseArgs
import System.IO.Unsafe
import Control.Monad
import Data.Maybe
import qualified Data.Vector.Unboxed		as V


main :: IO ()
main  
 = do	args	<- parseArgsIO ArgsComplete mainArgs
	
	when (gotArg args ArgHelp)
	 $ usageError args ""

	mainWithArgs args
	

mainWithArgs :: Args MainArg -> IO ()
mainWithArgs args
 = let	config		= loadConfig args

	-- The solver we're using to calculate the acclerations.
	solverName	= configSolverName config
	calcAccels	= fromMaybe (error $ unlines
					[ "unknown solver " ++ show solverName
					, "choose one of "  ++ (show $ map fst solvers) ])
			$ lookup solverName solvers
	
	-- Setup initial world
	vPoints 	= genPointsDisc 
				(configBodyCount config)
	 			(0, 0) 
				(configStartDiscSize config)

	vBodies		= V.map (setStartVelOfBody $ configStartSpeed config)
			$ V.map (setMassOfBody     $ configBodyMass   config)
			$ V.map (uncurry unitBody) 
			$ vPoints

	worldStart	= World
				{ worldBodies	= vBodies
				, worldSteps	= 0 }

				
    in	case configWindowSize config of
	 Just windowSize	-> mainGloss config calcAccels worldStart windowSize
	 Nothing		-> mainBatch config calcAccels worldStart 


-- | Run the simulation in a gloss window.
mainGloss 
	:: Config
	-> Solver	-- ^ Fn to calculate accels of each point.
	-> World	-- ^ Initial world.
	-> Int		-- ^ Size of window.
	-> IO ()
	
mainGloss config calcAccels worldStart windowSize
 = let	draw	= drawWorld (configShouldDrawTree config)

	advance _viewport time world	
	 = let	world'	= advanceWorld 
				(calcAccels $ configEpsilon config)
				(configTimeStep config)
				world

		-- if we've done enough steps then bail out now.
	   in	case configMaxSteps config of
	 	 Nothing		-> world'
	 	 Just maxSteps
	  	   | worldSteps world' < maxSteps	-> world'
	  
		   -- Gloss doesn't provide a clean way to end the animation...
	  	   | otherwise	
	  	   -> unsafePerformIO (endProgram (configDumpFinal config) world') 
			`seq` error "advanceWorld: we're finished, stop calling me."

   in	simulateInWindow
		"Barnes-Hutt"		-- window name
		(windowSize, windowSize)-- window size
		(10, 10)		-- window position
		black			-- background color
		(configRate config)	-- number of iterations per second
		worldStart		-- initial world
		draw			-- fn to convert a world to a picture
		advance			-- fn to advance the world


mainBatch config calcAccls worldStart
 = return ()
{-
 = go world	= go (advance world)
-}


-- | Call error to end the program.
endProgram 
	:: Maybe FilePath		-- ^ Write final bodies to this file.
	-> World			-- ^ Final world state.
	-> IO ()

endProgram mDumpFinal world
 = do
	-- Dump the final world state to file if requested.
	maybe 	(return ()) (dumpWorld world) mDumpFinal

	-- Call error to end program.
	error $ "done"

