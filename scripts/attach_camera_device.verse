<## ABOUT ## ===========================================================================================================================##
The attach camera device is a device that can be used to make a camera follow a prop. Beware that this is a experimental and not greatly 
optimized script.                                                                           
                                                                                                                                    
    By: Aitor Westerhof | Twitter: @TheCreaitor                                                                                                                                                                         
                                                                                                                                        
## ABOUT ## ===========================================================================================================================##>

using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

<# =========================================================================================================================== #>
    # Device: Attach Camera                                                                                                                                   
<# =========================================================================================================================== #>
attach_camera_device := class(creative_device):

    # The prop the camera should attach to.
    @editable   Prop : creative_prop = creative_prop{}

    # Constants ==============================================================================
        StandardZ : float = 0.0 # Z-position of the player (This version ignores the Z-position since this is another challenge)

        # Hardcoded speeds in cm/s
        ForwardSpeed : float = 550.0
        BackwardSpeed : float = 325.0
        LeftSpeed : float = 265.0
        RightSpeed : float = 265.0
        HaltSpeed : float = 0.0

        # Local rotation angle of the movements
        ForwardAngle : float = 0.0
        BackwardAngle : float = -180.0
        LeftAngle : float = -90.0
        RightAngle : float = 90.0
        HaltAngle : float = -180.000000
    # End of Constants =======================================================================

    # Variables ==============================================================================
    var MovementDirection : direction = direction.Halted # The direction the player is moving (As in pressing W A S D on their keyboard)
    var MoveDuration : float = 1.0 # The duration of one MoveTo without being interrupted
    var Sprinting : logic = false
    # End of Variables =======================================================================

    # OnBegin ================================================================================
    OnBegin<override>()<suspends> : void =
        # Get the first player
        AllPlayers := GetPlayspace().GetPlayers()
        if (Agent := AllPlayers[0], Player := player[Agent], FortCharacter := Player.GetFortCharacter[]):
            # Initialize position
            if (Prop.TeleportTo[vector3{ X := FortCharacter.GetTransform().Translation.X, Y := FortCharacter.GetTransform().Translation.Y, Z := StandardZ}, FortCharacter.GetTransform().Rotation]) {}
            spawn{ Mover(FortCharacter) }                               # Start the Mover
            spawn{ Interruptor() }                                      # Start the Interruptor
            spawn{ PlayerMovementTracker(FortCharacter) }               # Start the Player Movement Tracker
            FortCharacter.SprintedEvent().Subscribe(UpdateSprinting)    # Track if the player is sprinting
    # End of OnBegin =========================================================================

    # The Prop Mover =========================================================================
    Mover(FortCharacter : fort_character)<suspends> : void =
        var PreviousMovementDirection : direction = MovementDirection

        loop:
            Sleep(0.1) # If we use Sleep(0.0) we'll get a glitchy movement
            PredictedLocation : vector3 = PredictLocation(FortCharacter) # Predict the next location of the player

            if (MovementDirection = direction.Halted): # Player is not moving
                Prop.MoveTo(vector3{ X := FortCharacter.GetTransform().Translation.X, Y := FortCharacter.GetTransform().Translation.Y, Z := StandardZ}, FortCharacter.GetTransform().Rotation, 0.2)
            else if (MovementDirection = direction.Forward or MovementDirection = direction.Backward): # Player is moving forwards or backwards
                if (PreviousMovementDirection <> MovementDirection): # Player changed movement direction
                    Sleep(0.4) # Wait for player to get to full speed
                Prop.MoveTo(PredictedLocation, FortCharacter.GetTransform().Rotation, MoveDuration)
            else: # Player is moving left or right
                if (PreviousMovementDirection <> MovementDirection):  # Player changed movement direction
                    Sleep(0.1) # Wait for player to get to full speed
                Prop.MoveTo(PredictedLocation, FortCharacter.GetTransform().Rotation, MoveDuration)

            set PreviousMovementDirection = MovementDirection
    # =======================================================================================

    # Interrupts The Mover When Needed ======================================================
    Interruptor()<suspends> : void =
        var PreviousMovementDirection : direction = MovementDirection

        loop:
            Sleep(0.0)
            if (PreviousMovementDirection <> MovementDirection): # Player changed movement direction
                if (Prop.TeleportTo[Prop.GetTransform().Translation, Prop.GetTransform().Rotation]) {} # Interrupt the mover
                set PreviousMovementDirection = MovementDirection
    # =======================================================================================

    # Predict The Next Location =============================================================
    PredictLocation(FortCharacter : fort_character) : vector3 =
        LocalForward : vector3 = FortCharacter.GetTransform().Rotation.ApplyYaw(DegreesToRadians(GetDirectionAngle(MovementDirection))).GetLocalForward()   # Normalized vector in the direction of the movement
        PredictedLocation : vector3 = FortCharacter.GetTransform().Translation + (MoveDuration * GetDirectionVelocity(MovementDirection) * LocalForward)    # Predict the location
        return vector3{ X := PredictedLocation.X, Y := PredictedLocation.Y, Z := StandardZ}                                                                 # Ignore the Z
    # =======================================================================================

    # Track The Movement Of The Player ======================================================
    PlayerMovementTracker(FortCharacter : fort_character)<suspends> : void =
        # Initialize variables
        var PreviousElapsedTime : float = GetSimulationElapsedTime()
        var PreviousLocation : vector3 = vector3{ X := FortCharacter.GetTransform().Translation.X, Y := FortCharacter.GetTransform().Translation.Y, Z := StandardZ}
        var Displacements : queue = queue{}

        # Begin tracking
        loop:
            Sleep(0.0)

            # Calculate current movement statistics
            CurrenTime : float = GetSimulationElapsedTime()
            CurrentLocation : vector3 = vector3{ X := FortCharacter.GetTransform().Translation.X, Y := FortCharacter.GetTransform().Translation.Y, Z := StandardZ}
            CurrentDisplacement : float = Distance(PreviousLocation, CurrentLocation)
            Displacements.Insert(CurrentDisplacement)
            CurrentMean : float = Displacements.Mean()
            MovementAngle : float = GetMovementAngle(PreviousLocation, FortCharacter)

            # Decide what direction the player is moving in 
            if (Sprinting?):                                                                                                            # Player is sprinting (Pressing W)
                set MovementDirection = direction.Forward           
            if (CurrentMean.IsAlmostZero[1.0]):                                                                                         # Player is not moving 
                set MovementDirection = direction.Halted
            else if (MovementAngle = GetDirectionAngle(direction.Halted) or MovementAngle = GetDirectionAngle(direction.Halted) / 2.0): # Sometimes the movement angle is not calculated
                set MovementDirection = MovementDirection
            else if ((IsAlmostEqual[MovementAngle, GetDirectionAngle(direction.Left), 1.0]) and CurrentMean > 10.0):                    # Player is moving left (Pressing A)
                set MovementDirection = direction.Left 
            else if ((IsAlmostEqual[MovementAngle, GetDirectionAngle(direction.Right), 1.0] and CurrentMean > 10.0)):                   # Player is moving right (Pressing D)
                set MovementDirection = direction.Right
            else if ((IsAlmostEqual[MovementAngle, GetDirectionAngle(direction.Backward), 1.0])):                                       # Player is moving backwards (Pressing S)
                set MovementDirection = direction.Backward 

            # Update variables
            set PreviousElapsedTime = GetSimulationElapsedTime()
            set PreviousLocation = vector3{ X := FortCharacter.GetTransform().Translation.X, Y := FortCharacter.GetTransform().Translation.Y, Z := StandardZ}
    # =======================================================================================

    # Update Sprinting Variable =============================================================
    UpdateSprinting(FortCharacter : fort_character, Status : logic) : void =
        set Sprinting = Status
    # =======================================================================================

    # Get The Hardcoded Velocity ============================================================
    GetDirectionVelocity(Direction : direction) : float =
        case(Direction):
            direction.Forward =>
                return ForwardSpeed
            direction.Left =>
                return LeftSpeed
            direction.Right =>
                return RightSpeed
            direction.Backward =>
                return BackwardSpeed
            direction.Halted =>
                return HaltSpeed
    # =======================================================================================

    # Get The Hardcoded Movement Angle ======================================================
    GetDirectionAngle(Direction : direction)<transacts> : float =
        case(Direction):
            direction.Forward =>
                return ForwardAngle
            direction.Left =>
                return LeftAngle
            direction.Right =>
                return RightAngle
            direction.Backward =>
                return BackwardAngle
            direction.Halted =>
                return HaltAngle
    # =======================================================================================

    # Calculate Rotation Angle Compared To A Point  =========================================
    GetMovementAngle<public>(Point : vector3, FortCharacter : fort_character) : float =
        Transform : transform = FortCharacter.GetTransform()
        LocalForward : vector3 = Transform.Rotation.GetLocalForward()
        Dot : float = LocalForward.X * (Point.X - Transform.Translation.X) + LocalForward.Y * (Point.Y - Transform.Translation.Y)
        Angle : float = RadiansToDegrees(ArcCos(Dot / (LocalForward.Length() * (Point - Transform.Translation).Length()))) - 180.0
        Cross : vector3 = CrossProduct(LocalForward, (Point - Transform.Translation))

        if ( Cross.Z < 0.0):
            return -1.0 * Angle
        return Angle
    # =======================================================================================

# ======================================================================

# Data Structures  ======================================================================
direction := enum{Forward, Left, Right, Backward, Halted} # Directions a player can move in

# Just a quick and bad/not reusable queue data structure
queue := class():

    var Array : []float = array{0.0, 1.0, 2.0, 3.0, 4.0}
    MaxLength : int = 5

    GetElements() : []float =
        return Array

    Insert(Element : float) : []float =
        for (Range := 0..(MaxLength - 2), Index := (MaxLength - 1) - Range):
            if (set Array = Array.ReplaceElement[Index, Array[Index - 1]]) {}
        if (set Array = Array.ReplaceElement[0, Element]) {}
        return Array

    Mean() : float =
        var Sum : float = 0.0
        for (Element : Array):
            set Sum += Element
        return Sum / (MaxLength * 1.0)
# =======================================================================================
