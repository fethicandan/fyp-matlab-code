classdef RlcaAgent
    %AGENT Summary of this class goes here
    % Author: Dale Collison
    
    %% RlcaAgent - Properties
    properties
        iAgent % Number allocated to the agent
        position = zeros(1,2) % Current position of the agent
        Velocity = [0, 0]; % Velocity information
        preferredVelocity = [0,0];
        speed = AgentConstants.MAX_SPEED
        radius = [] % Collision radius of the agent
        heading = [] % Agent direction in degrees
        headingVector = []
        goal = zeros(1,2) % Goal position of the agent
        goalHeading = []
        prevDistanceToGoal = []
        distanceToGoal = [] % Current distance to agent goal
        neighbourhoodRadius = AgentConstants.NEIGHBOURHOOD_RADIUS % Observable space around the agent
        Neighbours = struct('position',[],'velocity',[],'radius',[]) % Information on agents currently within its neighbourhood
        neighbourIds = []
        distToNeighbour = []
        isAtGoal = 0 % Boolean to show if the agent has reached its intended goal
        hasCollided = 0 % Boolean to show if the agent has been in a collision
        color % Colour of the agent on the plot
        stateId = -1;
        PastStates = []
        actionId = -1;
        PastActions = []
        %         epsilon = RLConstants.INITIAL_EPSILON
    end
    
    %% RlcaAgent - Public Methods
    methods (Access = public)
        function obj = RlcaAgent(x0,y0,xg,yg,iAgent)
            obj.radius = AgentConstants.RADIUS;
            obj.checkcoordinates(x0,y0,xg,yg);
            obj.iAgent = iAgent;
            obj.color = obj.getcolor();
            obj.position = [x0, y0];
            obj.goal = [xg, yg];
            
            deltaP = obj.goal - obj.position;
            obj.goalHeading = atan2(deltaP(2),deltaP(1));
            
            [obj.heading, obj.headingVector] = obj.calcheading();
            
            obj.distanceToGoal = obj.calcdistancetogoal();
        end
        
        function obj = timestep(obj)
            
            obj.isAtGoal = obj.checkisatgoal();
            
            if ~obj.isAtGoal
                [obj.stateId] = obj.getstate();
                obj.PastStates = [obj.stateId, obj.PastStates];
                
                [obj.actionId, obj.heading, obj.Velocity] = obj.calcaction();
                
                obj.PastActions = [obj.actionId, obj.PastActions];
                
                obj.speed = norm(obj.Velocity);
                
                obj.position = calcposition(obj,EnvironmentConstants.TIME_STEP);
                
                obj.prevDistanceToGoal = obj.distanceToGoal;
                [obj.distanceToGoal, obj.goalHeading] = obj.calcdistancetogoal();
            else
                obj.stateId = 0;
                obj.PastStates = [obj.stateId, obj.PastStates];
                obj.actionId = 0;
                obj.PastActions = [obj.actionId, obj.PastActions];
                obj.speed = 0;
            end
            
        end
        
        function obj = addneighbour(obj,Neighbour)
            iNeighbour = find(obj.neighbourIds == Neighbour.iAgent);
            [nx, ny] = createarc(obj.heading + AgentConstants.VISION_ANGLE,...
                obj.heading - AgentConstants.VISION_ANGLE,obj.position(1),...
                obj.position(2),AgentConstants.NEIGHBOURHOOD_RADIUS);
            isWithinNeighbourhood = inpolygon(Neighbour.position(1),...
                Neighbour.position(2),nx,ny);
            
            if ~isempty(iNeighbour) && ~isWithinNeighbourhood % If an existing neighbour has exited the neighbourhood
                obj.Neighbours.position(iNeighbour,:) = [];
                obj.Neighbours.velocity(iNeighbour,:) = [];
                obj.Neighbours.radius(iNeighbour) = [];
                obj.neighbourIds(iNeighbour) = [];
                %                 createevent(['Agent ' num2str(obj.iAgent) ' Lost Agent ' num2str(Neighbour.iAgent)])
            elseif isWithinNeighbourhood
                if isempty(iNeighbour)
                    iNeighbour = length(obj.neighbourIds)+1;
                    obj.neighbourIds(end+1) = Neighbour.iAgent;
                    %                     createevent(['Agent ' num2str(obj.iAgent) ' Detected Agent ' num2str(Neighbour.iAgent)])
                end
                obj.Neighbours.position(iNeighbour,:) = Neighbour.position;
                obj.Neighbours.velocity(iNeighbour,:) = Neighbour.Velocity;
                obj.Neighbours.radius(iNeighbour,1) = Neighbour.radius;
            end
        end
        
    end
    
    %% RlcaAgent - Private Methods
    methods (Access = private)
        
        function [actionId, heading, Velocity] = calcaction(obj)
            global Q
            global A
            global epsilon
            global visitCount
            %             epsilon = obj.epsilon;
            if obj.stateId == 0 % No neighbours to worry about, go full speed at the goal.
                [Velocity] = obj.calcgoalvelocity();
                %                 actionId = obj.getactionid(Velocity);
                %                 heading = atan2(Velocity(2),Velocity(1));
            else
                % Choose an action
                sV = visitCount(:,:,obj.stateId);
                [r,c] = find(sV==0);
                nUnvisitedActions = nnz(r);
                if (rand >= epsilon) || nUnvisitedActions == 0 % Choose best option
                    sQ = Q(:,:,obj.stateId);
                    M = max(max(sQ));
                    [r,c] = find(sQ==M);
                    iR = 1;
                    iC = 1;
                    deltaP = obj.goal - obj.position;
                    gh = atan2(deltaP(2),deltaP(1))-pi/2;
                    translatedVelocity = obj.translatevelocity(A{r(1),c(1)},gh);
                    currentDeltaV = norm(obj.Velocity-translatedVelocity);
                    if length(r) > 1
                        for i = 1:length(r)
                            translatedVelocity = obj.translatevelocity(A{r(i),c(i)},gh);
                            deltaV = norm(obj.Velocity-translatedVelocity);
                            if deltaV < currentDeltaV
                                iR = i;
                                iC = i;
                                currentDeltaV = deltaV;
                            end
                            
                        end
                        r = r(iR);
                        c = c(iC);
                    end
                    Velocity = A{r,c};
                else % Try an unexplored
                    %                     sV = visitCount(:,:,obj.stateId);
                    %                     [r,c] = find(sV==0);
                    iR = 1;
                    iC = 1;
                    deltaP = obj.goal - obj.position;
                    gh = atan2(deltaP(2),deltaP(1))-pi/2;
                    translatedVelocity = obj.translatevelocity(A{r(1),c(1)},gh);
                    currentDeltaV = norm(obj.Velocity-translatedVelocity);
                    if length(r) > 1
                        for i = 1:length(r)
                            translatedVelocity = obj.translatevelocity(A{r(i),c(i)},gh);
                            deltaV = norm(obj.Velocity-translatedVelocity);
                            if deltaV < currentDeltaV
                                iR = i;
                                iC = i;
                                currentDeltaV = deltaV;
                            end
                            
                        end
                        r = r(iR);
                        c = c(iC);
                    end
                    Velocity = A{r,c};
                end
            end
            deltaP = obj.goal - obj.position;
            gh = atan2(deltaP(2),deltaP(1))-pi/2;
            translatedVelocity = obj.translatevelocity(Velocity,gh);
            translatedVelocity = obj.matchvelocity(translatedVelocity);
            actionId = obj.getactionid(Velocity);
            heading = atan2(translatedVelocity(2),translatedVelocity(1));
            Velocity = translatedVelocity;
            
        end
        
        function [stateId] = getstate(obj)
            global S
            if isempty(obj.neighbourIds)
                stateId = 0;
            else
                p = obj.position;
                np = obj.Neighbours.position;
                h = obj.heading;
                deltaP = obj.goal - obj.position;
                gh = atan2(deltaP(2),deltaP(1));
                
                npTranslated = obj.translateneighbourposition(p,np,gh);
                
                npTranslated = 10*round(npTranslated/10);
                
                if norm(npTranslated) > 60
                    signs = npTranslated./abs(npTranslated);
                    npTranslated = abs(npTranslated);
                    [~,idx] = max(npTranslated);
                    npTranslated(idx) = npTranslated(idx) - 10;
                    npTranslated = npTranslated.*signs;
                end
                
                matS = [S{:}];
                stateId = (strfind(matS,npTranslated) + 1)/2;
                if length(stateId) > 1
                    idx = floor(stateId) == stateId;
                    stateId = stateId(idx);
                end
                stateId = floor(stateId);
            end
        end
        
        function velocityTranslated = translatevelocity(obj,Velocity,theta)
            
            rotationMatrix = [cos(theta), -sin(theta); sin(theta), cos(theta)];
            
            velocityTranslated = (rotationMatrix*Velocity')';
            
            %             velocityTranslated = obj.matchvelocity(velocityTranslated);
            
        end
        
        function npTranslated = translateneighbourposition(~,p,np,gh)
            % TODO: Translate the position of the neighbour to be relative
            % to the agent's position and in the direction of its goal.
            deltaPNeighbour = (np - p);
            deltaH = -gh+pi/2;
            
            rotationMatrix = [cos(deltaH), -sin(deltaH); sin(deltaH), cos(deltaH)];
            
            npTranslated = (rotationMatrix*deltaPNeighbour')';
            
        end
        
        function [Velocity] = calcgoalvelocity(obj)
            
            deltaP = obj.goal - obj.position;
            headingVector = deltaP/norm(deltaP);
            Velocity = headingVector*AgentConstants.MAX_SPEED;
            theta = -atan2(deltaP(2),deltaP(1))+pi/2;
            Velocity = obj.translatevelocity(Velocity,theta);
            Velocity = round(Velocity,6);
            Velocity = obj.matchvelocity(Velocity);
            if nnz(isnan(Velocity)) > 0
                1;
            end
            
        end
        
        function [Velocity] = matchvelocity(~,exactVelocity)
            [v,~] = pol2cart(linspace(0, pi, 51), AgentConstants.MAX_SPEED);
            v = round(v,3);
            Velocity = interp1(v,v,exactVelocity,'nearest');
            
        end
        
        function actionId = getactionid(~,Velocity)
            global A
            matA = [A{:}];
            actionId = (strfind(matA,Velocity) + 1)/2;
            if length(actionId) > 1
                idx = floor(actionId) == actionId;
                actionId = actionId(idx);
            end
        end
        
        function [distanceToGoal, goalHeading] = calcdistancetogoal(obj)
            deltaX = abs(obj.position(1) - obj.goal(1));
            deltaY = abs(obj.position(2) - obj.goal(2));
            distanceToGoal = hypot(deltaX,deltaY);
            deltaP = obj.goal - obj.position;
            goalHeading = atan2(deltaP(2),deltaP(1));
        end
        
        function actualVelocity = calcvelocity(obj)
            actualVelocity = obj.speed*obj.headingVector;
        end
        
        function position = calcposition(obj,deltaT)
            position(1) = round(obj.position(1) + (obj.speed*deltaT)*...
                cos(obj.heading),4);
            position(2) = round(obj.position(2) + (obj.speed*deltaT)*...
                sin(obj.heading),4);
        end
        
        function [heading, headingVector] = calcheading(obj)
            deltaP = obj.goal - obj.position;
            headingVector = deltaP/norm(deltaP);
            heading = atan2(deltaP(2),deltaP(1));
            
        end
        
        function isAtGoal = checkisatgoal(obj)
            deltaP = obj.goal - obj.position;
            
            deltaX = abs(deltaP(1));
            deltaY = abs(deltaP(2));
            
            isAtGoal = deltaX <= AgentConstants.GOAL_MARGIN &&...
                deltaY <= AgentConstants.GOAL_MARGIN;
        end
        
        function color = getcolor(obj)
            iColor = obj.iAgent;
            if iColor > 9
                iColor = mod(iColor,9);
            end
            color = AgentConstants.COLOR_ORDER(iColor,1:end);
        end
        
        function checkcoordinates(~,x0,y0,xg,yg)
            isWithinX = nnz(([x0,xg] < EnvironmentConstants.X_BOUNDARY(1))...
                | [x0,xg] > EnvironmentConstants.X_BOUNDARY(2)) == 0;
            isWithinY = nnz(([y0,yg] < EnvironmentConstants.Y_BOUNDARY(1))...
                | [y0,yg] > EnvironmentConstants.Y_BOUNDARY(2)) == 0;
            if ~isWithinX || ~isWithinY
                error('Coordinates outside of environment boundaries.')
            end
        end
        
    end
    
end

