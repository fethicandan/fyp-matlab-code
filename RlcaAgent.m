classdef RlcaAgent
    %AGENT Summary of this class goes here
    % Author: Dale Collison
    
    %% RlcaAgent - Properties
    properties
        iAgent % Number allocated to the agent
        position = zeros(1,2) % Current position of the agent
        Velocity = struct('desired',[],'actual',[]) % Velocity information
        preferredVelocity = [0,0];
        speed = AgentConstants.MAX_VELOCITY
        radius = [] % Collision radius of the agent
        heading = [] % Agent direction in degrees
        headingVector = []
        goal = zeros(1,2) % Goal position of the agent
        distanceToGoal = [] % Current distance to agent goal
        neighbourhoodRadius = AgentConstants.NEIGHBOURHOOD_RADIUS % Observable space around the agent
        Neighbours = struct('position',[],'velocity',[],'radius',[]) % Information on agents currently within its neighbourhood
        neighbourIds = []
        isAtGoal = 0 % Boolean to show if the agent has reached its intended goal
        hasCollided = 0 % Boolean to show if the agent has been in a collision
        color % Colour of the agent on the plot
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
            [obj.heading, obj.headingVector] = obj.calcheading();
            obj.Velocity.actual = obj.calcvelocity();
            obj.speed = norm(obj.Velocity.actual);
            obj.distanceToGoal = obj.calcdistancetogoal();
        end
        
        function obj = timestep(obj)
%                         % Agent follows cursor
%                         A = get(0, 'PointerLocation');
%                         obj.goal(1) = (A(1)-1306)/4.69;
%                         obj.goal(2) = (A(2)-740)/4.69;
            
            obj.isAtGoal = obj.checkisAtGoal();
            if ~obj.isAtGoal
                obj.heading = obj.calcheading();
                obj.Velocity.actual = obj.calcvelocity();
                obj.speed = norm(obj.Velocity.actual);
                obj.position = calcposition(obj,EnvironmentConstants.TIME_STEP);
                obj.distanceToGoal = obj.calcdistancetogoal();
            else
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
                createevent(['Agent ' num2str(obj.iAgent) ' Lost Agent ' num2str(Neighbour.iAgent)])
            elseif isWithinNeighbourhood
                if isempty(iNeighbour)
                    iNeighbour = length(obj.neighbourIds)+1;
                    obj.neighbourIds(end+1) = Neighbour.iAgent;
                    createevent(['Agent ' num2str(obj.iAgent) ' Detected Agent ' num2str(Neighbour.iAgent)])
                end
                obj.Neighbours.position(iNeighbour,:) = Neighbour.position;
                obj.Neighbours.velocity(iNeighbour,:) = Neighbour.Velocity.actual;
                obj.Neighbours.radius(iNeighbour,1) = Neighbour.radius;
            end
        end
        
    end
    
    %% RlcaAgent - Private Methods
    methods (Access = private)
        
        function distanceToGoal = calcdistancetogoal(obj)
            deltaX = abs(obj.position(1) - obj.goal(1));
            deltaY = abs(obj.position(2) - obj.goal(2));
            distanceToGoal = hypot(deltaX,deltaY);
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
            MAX_DELTA_THETA = pi/50;
            deltaP = obj.goal - obj.position;
            headingVector = deltaP/norm(deltaP);
            prevHeading = obj.heading;
            heading = atan2(deltaP(2),deltaP(1));
%             if ~isempty(obj.Neighbours.position)
%                heading = obj.heading + MAX_DELTA_THETA; 
%             else
%                 heading = atan2(deltaP(2),deltaP(1));
%             end
%             
%             if (abs(prevHeading-heading) > MAX_DELTA_THETA)
%                 if prevHeading < heading
%                    heading = prevHeading + MAX_DELTA_THETA; 
%                 else
%                     heading = prevHeading - MAX_DELTA_THETA; 
%                 end             
%             end           
        end
        
        function isAtGoal = checkisAtGoal(obj)
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

