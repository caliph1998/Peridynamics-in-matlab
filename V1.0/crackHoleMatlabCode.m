close all

  
u = symunit;
%length: Total length of the plate
length = 0.5; % Unit: m
%width: Total width of the plate
width = 0.5; % Unit: m
%adding a hole in the plate
radius_a = 0.05; % Unit: m
radius_b = 0.05;
ellipse_curvature = radius_b ^ 2 / radius_a;
radius_path = 0.08;
% time unit
dt = 1;
% Elastic modulus
Elastic_Modulus = 200e9; % unit: N/m^2
% possion ratio
Possion_ratio = 0.3;  
%NumofDiv_x: Number of divisions in x direction
NumofDiv_x = 50;
%NumofDiv_y: Number of divisions in y direction
NumofDiv_y = NumofDiv_x;
%TimeInterval: Number of time iTimeIntervalervals
TimeInterval = 2500;
%Applied_pressure: Applied pressure
Applied_pressure = 500e7; % unit: N/m^2
% total number of material point
%TotalNumMatPoint = NumofDiv_x*NumofDiv_y;
InitialTotalNumMatPoint = NumofDiv_x*NumofDiv_y;
%Maximum number of material poiTimeIntervals in the horizon
maxfam = 200;
%dx: Incremental distance
dx = length / NumofDiv_x;
%thick: Thickness of the plate
%delta: Horizon
delta = 3.015 * dx; % unit: m
% Thickness of matrial
thick = dx; % unit: m
% volume correction related number
VolCorr_radius = dx / 2;
% shear modulus % unit: N/m^2
Shear_Modulus = Elastic_Modulus / (2 * (1 + Possion_ratio)); 
% bulk modulus % unit: N/m^2
Bulk_Modulus = Elastic_Modulus / (2 * (1 - Possion_ratio)); 
% PD material parameter
alpha=0.5*(Bulk_Modulus-2*Shear_Modulus);
%area: Cross-sectional area
Area = dx * dx; % unit: m^2
%Volume: Volumeume of a material point
Volume = Area * thick; % unit: m^3
% PD material parameter
bcd = 2/(pi*thick*delta^3);
% PD material Parameter
bcs = 6*Shear_Modulus/(pi*thick*delta^4);
% Classical strain energy for dilatation
SED_analytical_dilatation = 0.001;
% PD strain energy for distorsion=
SED_analytical_distorsion = 1 / (2*(1 - Possion_ratio*Possion_ratio)) * (Elastic_Modulus) * (0.001)^2 - alpha * (0.001)^2; 
Volume_Horizon = pi * delta ^ 2 * thick; % The volume of the spherical horzion of each material point
   

%nullpoint = ones(InitialTotalNumMatPoint, 1);
neighborsPerNode = floor(pi * delta ^ 2 / Area);
totalNumOfBonds = InitialTotalNumMatPoint * neighborsPerNode;
nodefam = zeros(totalNumOfBonds,3); % Total array allocated to storing the neighbors of every material point and their bondforces

nnum = 0; 
coord_excess = zeros(InitialTotalNumMatPoint, 2);
%%
%VARIABLES OF THE CRACK TIP HOLES
tipNumOfDiv = 800;
tip_radius = radius_a / 5;
dx_tip = tip_radius / tipNumOfDiv * 40; %Recommended material point sizes at the crack tips
%dx_tip = 6.25e-04;
%%
path_horizontal = [];
%Defining the tips and the ellipse hole regions using class ellipseClass
% Constructor: ellipseClass(x_origin, y_origin_, major radius, minor radius);
center_hole = ellipseClass(0, 0, radius_a, radius_b);
left_tip = ellipseClass((-1) * radius_a, 0, tip_radius, tip_radius); %if major and minor radii are equal => circle.
right_tip = ellipseClass(radius_a, 0, tip_radius, tip_radius);
%%
% coordinate generation for each material point
for i = 1:NumofDiv_x
    for j = 1:NumofDiv_y
      coordx = -1/2*length + (dx/2) + (i - 1)*dx;
      coordy = -1/2*width + (dx/2) + (j - 1)*dx;
      
      %Applying the hole in the plate (can be deactivated by commenting the
      %if statement below%
      
      if (center_hole.inEllipse(coordx, coordy))
          continue
          %nullpoint(nnum,1) = 0;
      end
      
      %Defining paths of material points similar to the path feature in
      %ABAQUS%%%%%%%(ONLY THE HORIZONTAL PATH WORKS)
      if ( abs(coordy) <= dx && coordx >= 0 && coordy > 0)
          path_horizontal(end+1) = nnum + 1;
      end
      nnum = nnum + 1;
      coord_excess(nnum,1) = coordx; %A coord_excess is defined since initially a larger than needed array size has to be used.
      coord_excess(nnum,2) = coordy; %coord-excess is trimmed later as the end elements are empty.
       
    end
end

%%
coord = coord_excess(1:nnum, :); %coord: Material point locations
% get_circle(X, Y, R, dx, mid_circle)
%%
%EXTRACTING COORDINATES OF THE CRACK TIP LOCAL MATERIAL
%POINTS FROM get_circle AND IMPORTING THEM INTO COORD
%seedLeft = get_circle(left_tip.x_center, left_tip.y_center, left_tip.radius_major, dx_tip, center_hole);
%seedRight = get_circle(right_tip.x_center, right_tip.y_center, right_tip.radius_major, dx_tip, center_hole);
%coord = [coord; seedLeft; seedRight];

S = size(coord); %THE TOTAL NUMBER OF MATERIAL POINTS HAS TO BE UPDATED
TotalNumMatPoint = S(1);
%%
Deltas = zeros(TotalNumMatPoint, 1);
for i = 1: nnum
    Deltas(i, 1) = delta;
end
for i = nnum+1: TotalNumMatPoint
    Deltas(i, 1) = 3.015 * dx_tip;
end

%% Definition of needed arrays (coord_excess is trimmed at this stage)
numfam = zeros(TotalNumMatPoint,1); %numfam: Number of family nodes
pointfam = zeros(TotalNumMatPoint,1); %pointfam: Pointer
PDforce = zeros(TotalNumMatPoint,2);%PDforce: Peridynamic force
BodyForce = zeros(TotalNumMatPoint,2);%Body force
%%
path_horizontal = SortPath('hor',path_horizontal, coord); %Sorting horizontal path from head to tail of the path
%path_edge = SortPath('edge',path_edge, coord);
%path_circular = SortPath('circle',path_circular, coord);
%%
PDforceold = zeros(TotalNumMatPoint,2);
PD_SED_distorsion = zeros(TotalNumMatPoint,2);
SurCorrFactor_dilatation = zeros(TotalNumMatPoint,2); % PD surface correction factor for dilatation
SurCorrFactor_dilatationold = zeros(TotalNumMatPoint,2);% PD surface correction factor old for dilatation
SurCorrFactor_distorsion = zeros(TotalNumMatPoint,2); % PD surface correction factor old for dilatation
SurCorrFactor_distorsionold = zeros(TotalNumMatPoint,2); % PD surface correction factor old for distorsion
disp = zeros(TotalNumMatPoint,2); % displacement
total_disp = zeros(TotalNumMatPoint,2); %The total sum of displacement for each material point
vel = zeros(TotalNumMatPoint,2); % velocity
velhalfold = zeros(TotalNumMatPoint,2);% velocity of half old
velhalf = zeros(TotalNumMatPoint,2); % velocity of half
acc = zeros(TotalNumMatPoint,2); % acceleration
massvec = zeros(TotalNumMatPoint,2);% mass vector
PD_SED_dilatation = zeros(TotalNumMatPoint,2); % Peridynamic strain energy density for dilatation
PD_SED_dilatation_Fixed = zeros(TotalNumMatPoint,2); % Fixed Peridynamic strain energy density for dilatation
Check_time = zeros(TimeInterval,1);
Steady_check_x = zeros(TimeInterval,1);
Steady_check_y = zeros(TimeInterval,1);
%% NEW NEIGHBOR DEFNITIONS
neighbors = zeros(TotalNumMatPoint, neighborsPerNode);
neighborsIter = ones(TotalNumMatPoint, 1);
dualNeighbors = zeros(TotalNumMatPoint, neighborsPerNode);
dualIter = ones(TotalNumMatPoint, 1);
for i = 1:TotalNumMatPoint
    
    for j = 1:TotalNumMatPoint
        RelativePosition_Vector = sqrt((coord(j,1) - coord(i,1))^2 + (coord(j,2) - coord(i,2))^2);
        if(i~=j) 
            if(RelativePosition_Vector <= Deltas(i, 1))
            neighbors(i, neighborsIter(i,1)) = j;
            neighborsIter(i,1) = neighborsIter(i,1) + 1;
            if(RelativePosition_Vector > Deltas(j, 1))
                dualNeighbors(j, dualIter(j, 1)) = i;
                dualIter(j, 1) = dualIter(j, 1) + 1;
            end
            end
        end
    end
end
%%

% coordinate displays with horizon families
for i = 1:TotalNumMatPoint

    if (i == 1) 
    pointfam(i,1) = 1;
    else
    pointfam(i,1) = pointfam(i-1,1) + numfam(i-1,1);
    end

    for j = 1:TotalNumMatPoint
        RelativePosition_Vector = sqrt((coord(j,1) - coord(i,1))^2 + (coord(j,2) - coord(i,2))^2);
        if(i~=j) 
            if(RelativePosition_Vector <= delta)
            numfam(i,1) = numfam(i,1) + 1;
            nodefam(pointfam(i,1)+numfam(i,1)-1,1) = j;
            end
        end
    end
end


%Surface correction factor calculation - start
for i = 1:TotalNumMatPoint
disp(i,1) = 0.001*coord(i,1);
disp(i,2) = 0.0;
end

%%Surface correction factor calculation - function%%
[PD_SED_distorsion(:,1),SurCorrFactor_distorsion(:,1),PD_SED_dilatation(:,1), SurCorrFactor_dilatation(:,1)] = Calculate_SurCorrection(delta,VolCorr_radius,bcs,bcd,Volume,SED_analytical_distorsion,SED_analytical_dilatation,disp,TotalNumMatPoint,numfam,nodefam,pointfam,coord);
    
for i = 1:TotalNumMatPoint
    disp(i,1) = 0;
    disp(i,2) = 0.001 * coord(i,2);
end
[PD_SED_distorsion(:,2), SurCorrFactor_distorsion(:,2),PD_SED_dilatation(:,2), SurCorrFactor_dilatation(:,2)] = Calculate_SurCorrection(delta,VolCorr_radius,bcs,bcd,Volume,SED_analytical_distorsion,SED_analytical_dilatation,disp,TotalNumMatPoint,numfam,nodefam,pointfam,coord);
%Surface correction factor calculation - end
    
%initial displacemeTimeInterval
for i = 1:TotalNumMatPoint
disp(i,1) = 0;
disp(i,2) = 0; 
end


%Stable mass vector computation
for i = 1:TotalNumMatPoint
massvec(i,1) = 0.25 * dt * dt * (pi * (delta)^2 * thick)  * bcs / dx * 5;
massvec(i,2) = 0.25 * dt * dt * (pi * (delta)^2 * thick) * bcs / dx * 5;
end

%%
%%%% apply boundary conditions %%%

%{
%Applied loading - Left
for i = 1:NumofDiv_y
BodyForce(i,1) = -1 * Applied_pressure/dx;% * (coord(i,2) * 2 + 0.5);
end


%Applied loading - Right
for i = (nnum-NumofDiv_y+1):nnum
BodyForce(i,1) = Applied_pressure/dx;% * (coord(i,2) * 2 + 0.5);
end
%}
%{
for i = 1:TotalNumMatPoint
    if (coord(i,1) == min(coord(:,1)))
        BodyForce(i,1) = -1 * Applied_pressure/dx;
    elseif(coord(i,1) == max(coord(:,1)))
        BodyForce(i,1) = Applied_pressure/dx;
    end
end
%}
%{
%Applied loading - Left
for i = 1:NumofDiv_y
BodyForce(i,1) = -1 * Applied_pressure/dx;
end

%Applied loading - Right
for i = (nnum-NumofDiv_y+1):nnum
BodyForce(i,1) = Applied_pressure/dx;
end
%}


for i = 1:TotalNumMatPoint
    if (coord(i,2) == min(coord(:,2)))
        BodyForce(i,2) = (-1) * Applied_pressure/dx;
    elseif(coord(i,2) == max(coord(:,2)))
        BodyForce(i,2) =  Applied_pressure/dx;
    end
end
%%

testNode = 555;


%%%% Time Interval starts for computing displament of each material point %%% 
for tt = 1:TimeInterval
ctime = tt * dt;
time = tt

    dforce_x_Sum = 0;
    dforce_y_Sum = 0;
    
    for i = 1:TotalNumMatPoint
    PD_SED_dilatation_Fixed(i,1) = 0;
        for j = 1:numfam(i,1)
         cnode = nodefam(pointfam(i,1)+j-1,1);
         RelativePosition_Vector = sqrt((coord(cnode,1) - coord(i,1))^2 + (coord(cnode,2) - coord(i,2))^2);
         RelativeDisp_Vector=sqrt((coord(cnode,1)+disp(cnode,1)-coord(i,1)-disp(i,1))^2+(coord(cnode,2)+disp(cnode,2)-coord(i,2)-disp(i,2))^2);
         Stretch = (RelativeDisp_Vector - RelativePosition_Vector) / RelativePosition_Vector;
         AbsoluteValue_x_y = RelativeDisp_Vector * RelativePosition_Vector;
         Coeff_x = (coord(cnode,1) + disp(cnode,1) - coord(i,1) - disp(i,1)) * (coord(cnode,1) - coord(i,1));
         Coeff_y = (coord(cnode,2) + disp(cnode,2) - coord(i,2) - disp(i,2)) * (coord(cnode,2) - coord(i,2));
         Directional_cosine = (Coeff_x + Coeff_y) / AbsoluteValue_x_y;
            if (RelativePosition_Vector <= delta-VolCorr_radius) 
            fac = 1;
            elseif (RelativePosition_Vector <= delta+VolCorr_radius)
            fac = (delta+VolCorr_radius-RelativePosition_Vector)/(2*VolCorr_radius);
            else
            fac = 0;
            end

            if (abs(coord(cnode,2) - coord(i,2)) <= 1e-10)
            theta = 0;
            elseif (abs(coord(cnode,1) - coord(i,1)) <= 1e-10)
            theta = 90*pi/180;
            else
            theta = atan(abs(coord(cnode,2) - coord(i,2)) / abs(coord(cnode,1) - coord(i,1)));
            end

            SurCorrFactor_x = (SurCorrFactor_dilatation(i,1) + SurCorrFactor_dilatation(cnode,1))/2;
            SurCorrFactor_y = (SurCorrFactor_dilatation(i,2) + SurCorrFactor_dilatation(cnode,2))/2;
            SurCorrFactor_Arbitrary_distorsion = 1 / (((cos(theta))^2/(SurCorrFactor_x)^2) + ((sin(theta))^2 / (SurCorrFactor_y)^2));
            SurCorrFactor_Arbitrary_distorsion = sqrt(SurCorrFactor_Arbitrary_distorsion);

            %Critic stretch if statement is deactivated as it is unused
            %if (failm(i,j)==1) 
            PD_SED_dilatation_Fixed(i,1) = PD_SED_dilatation_Fixed(i,1) + bcd * delta * Stretch * Directional_cosine * Volume * SurCorrFactor_Arbitrary_distorsion * fac;                          
            %else
            %PD_SED_dilatation_Fixed(i,1) = 0;
            %end                                             
        end
    end

for i = 1:TotalNumMatPoint
    PDforce(i,1) = 0;
    PDforce(i,2) = 0;
    for j = 1:numfam(i,1)
    cnode = nodefam(pointfam(i,1)+j-1,1); %cnode: the current neighbor node/material-point.
    RelativePosition_Vector = sqrt((coord(cnode,1) - coord(i,1))^2 + (coord(cnode,2) - coord(i,2))^2); %the initial distance
    %The final distance
    RelativeDisp_Vector=sqrt((coord(cnode,1)+disp(cnode,1)-coord(i,1)-disp(i,1))^2+(coord(cnode,2)+disp(cnode,2)-coord(i,2)-disp(i,2))^2);
    Stretch = (RelativeDisp_Vector - RelativePosition_Vector) / RelativePosition_Vector;
% Consider A/A' as center node and C/C' as current neighbor node, then:
    AbsoluteValue_x_y = RelativeDisp_Vector * RelativePosition_Vector;
    Coeff_x = (coord(cnode,1) + disp(cnode,1) - coord(i,1) - disp(i,1)) * (coord(cnode,1) - coord(i,1)); %(C'x - Cx)(Cx-Ax)
    Coeff_y = (coord(cnode,2) + disp(cnode,2) - coord(i,2) - disp(i,2)) * (coord(cnode,2) - coord(i,2)); %(C'y - Cy)(Cy-Ay)
        Directional_cosine = (Coeff_x + Coeff_y) / AbsoluteValue_x_y; %Some weird constant that will be used in bond_constant calculations.
        if (RelativePosition_Vector <= delta-VolCorr_radius) %if all the way inside the horizon
         fac = 1;
        elseif (RelativePosition_Vector <= delta+VolCorr_radius) %if partially inside the A horizon
         fac = (delta+VolCorr_radius-RelativePosition_Vector)/(2*VolCorr_radius); %VolCorr_radius = dx / 2
        else
         fac = 0; %Unnecassary else since it will never happen
        end
        if (abs(coord(cnode,2) - coord(i,2)) <= 1.0e-10) %if both C and A were on a horizontal line
         theta = 0;
        elseif (abs(coord(cnode,1) - coord(i,1)) <= 1.0e-10) %if both C and A were on a vertical line
         theta = 90 * pi / 180;
        else
         theta = atan(abs(coord(cnode,2) - coord(i,2)) / abs(coord(cnode,1) - coord(i,1))); %theta: C and A angle
        end

        SurCorrFactor_x = (SurCorrFactor_distorsion(i,1) + SurCorrFactor_distorsion(cnode,1)) / 2;
        SurCorrFactor_y = (SurCorrFactor_distorsion(i,2) + SurCorrFactor_distorsion(cnode,2)) / 2;
        SurCorrFactor_Arbitrary_distorsion = 1 / (((cos(theta))^2/(SurCorrFactor_x)^2) + ((sin(theta))^2/(SurCorrFactor_y)^2));
        SurCorrFactor_Arbitrary_distorsion = sqrt(SurCorrFactor_Arbitrary_distorsion);
        %Note: same variable SurCorrFactor_x and SurCorrFactor_y are used
        %to hold two different concepts as variables.
        SurCorrFactor_x = (SurCorrFactor_dilatation(i,1) + SurCorrFactor_dilatation(cnode,1)) / 2;
        SurCorrFactor_y = (SurCorrFactor_dilatation(i,2) + SurCorrFactor_dilatation(cnode,2)) / 2;
        SurCorrFactor_Arbitrary_dilatation = 1 / (((cos(theta))^2 / (SurCorrFactor_x)^2) + ((sin(theta))^2 / (SurCorrFactor_y)^2));
        SurCorrFactor_Arbitrary_dilatation = sqrt(SurCorrFactor_Arbitrary_dilatation);
% bcd = d in Madenci; bcs: b in Madenci; PD_SED_dilatation_Fixed: thetha_k
% in madenci; SurCorrFactor_Arbitrary_dilation: Gd in Madenci;
% SurCorrFactor_Arbitrary_distorction: Gb in Madenci; Directional_cosine:
% Arrowhead_k_j in Madenci; alpha: a in madenci
%So here it seems t_kj and t_jk are summed up to form bonForce_const
%instead of using their difference.
%Anyway, in order to apply the dual horizon, you need to use t_kj of all
%the neighbors BUT t_jk of only those who are in your dual horizon (i.e.
%recognize you as well).
%For points with smaller horizon, this doesn't make a difference, but it
%does make a difference for the points with the larger horizon at the
%vicinity of the smaller horzion points.
        bondForce_const = (2 * bcd*delta * alpha / RelativePosition_Vector * Directional_cosine * (PD_SED_dilatation_Fixed(i,1) + ...
                      PD_SED_dilatation_Fixed(cnode,1))* SurCorrFactor_Arbitrary_dilatation + ...
                      4 * bcs*delta * Stretch * SurCorrFactor_Arbitrary_distorsion) * Volume * fac / RelativeDisp_Vector;
        %The point of the two lines below is to split the force vector into its components.
        %But it needs to be divided by RelativeDisp_Vector which is done in
        %the above line which is unclear and confusing.
        BondForce_x =  (coord(cnode,1) + disp(cnode,1) - coord(i,1) - disp(i,1)) * bondForce_const ;           
        BondForce_y =  (coord(cnode,2) + disp(cnode,2) - coord(i,2) - disp(i,2)) * bondForce_const ;           
        BondForce = (BondForce_x ^ 2 + BondForce_y ^ 2) ^ 0.5; %exactly the same as bondForce_const => Pointless!
        
        PDforce(i,1) = PDforce(i,1) + BondForce_x;     
        PDforce(i,2) = PDforce(i,2) + BondForce_y;
        nodefam(pointfam(i,1)+j-1,2) = BondForce_x;
        nodefam(pointfam(i,1)+j-1,3) = BondForce_y;
    end
end


%%% Getting steady-state solutions through Adaptive Dynamic relaxation %%%
cn1 = 0;
cn2 = 0;
for i = 1:TotalNumMatPoint
    if (velhalfold(i,1)~=0)
    cn1 = cn1 - disp(i,1) * disp(i,1) * (PDforce(i,1) / massvec(i,1) - PDforceold(i,1) / massvec(i,1)) / (dt * velhalfold(i,1));
    end
    
    if (velhalfold(i,2)~=0) 
    cn1 = cn1 - disp(i,2) * disp(i,2) * (PDforce(i,2) / massvec(i,2) - PDforceold(i,2) / massvec(i,2)) / (dt * velhalfold(i,2));
    end
    
    cn2 = cn2 + disp(i,1) * disp(i,1);
    cn2 = cn2 + disp(i,2) * disp(i,2);
end

    if (cn2~=0)
        if ((cn1 / cn2) > 0) 
        cn = 2 * sqrt(cn1 / cn2);
        else
        cn = 0;
        end
    else
    cn = 0;
    end

    %if (cn > 2)
    %cn = 1.9;
    %end

    for i = 1:TotalNumMatPoint
        if (tt == 1)
        velhalf(i,1) = 1 * dt / massvec(i,1) * (PDforce(i,1) + BodyForce(i,1)) / 2;		
        velhalf(i,2) = 1 * dt / massvec(i,2) * (PDforce(i,2) + BodyForce(i,2)) / 2;
        else	
        velhalf(i,1) = ((2 - cn * dt) * velhalfold(i,1) + 2 * dt / massvec(i,1) * (PDforce(i,1) + BodyForce(i,1))) / (2 + cn * dt);
        velhalf(i,2) = ((2 - cn * dt) * velhalfold(i,2) + 2 * dt / massvec(i,2) * (PDforce(i,2) + BodyForce(i,2))) / (2 + cn * dt);
        end
        
        %%%Deactivated velocity calculation that had no use%%%
        vel(i,1) = 0.5 * (velhalfold(i,1) + velhalf(i,1));
        vel(i,2) = 0.5 * (velhalfold(i,2) + velhalf(i,2));
        disp(i,1) = disp(i,1) + velhalf(i,1) * dt;
        disp(i,2) = disp(i,2) + velhalf(i,2) * dt;
        total_disp(i,1) = total_disp(i,1) + disp(i,1);
        total_disp(i,2) = total_disp(i,2) + disp(i,2);       
        velhalfold(i,1) = velhalf(i,1);
        velhalfold(i,2) = velhalf(i,2);
        PDforceold(i,1) = PDforce(i,1);
        PDforceold(i,2) = PDforce(i,2);
    end

Check_time(tt,1)= tt;
Steady_check_x(tt,1) = disp(testNode,1);
Steady_check_y(tt,1) = disp(testNode,2);
end
%time interval iteration ends

% 50*40 +(25+12) = 2037
%%
Dongjun_hole_stress = CalculateStressforPoint(coord,TotalNumMatPoint,numfam,nodefam, pointfam, thick);
unpunched_d = coord(path_horizontal(1),1) - coord(path_horizontal(end),1); %Distance from the crack tip to the plate edge
unpunched_d = unpunched_d * (-1);
normal_path_horizontal = (coord(path_horizontal,1) - coord(path_horizontal(1),1)) / (unpunched_d); %normalized path distance
testnode = 3000;
%%
%DEFORMED VS UNDEFORMED FIGURE
figure(1)
hold on
h1=plot(coord(:,1),coord(:,2),'.r');
h2=plot(coord(:,1)+disp(:,1),coord(:,2)+disp(:,2),'.b');
h3=plot(coord(testNode,1),coord(testNode,2),'ro','MarkerSize',3.3,'MarkerFaceColor','r');
h4=plot(coord(testNode,1)+disp(testNode,1),coord(testNode,2)+disp(testNode,2),'bo','MarkerSize',3.3,'MarkerFaceColor','b');
legend([h1 h2 h3 h4],{'Undeformed state','Deformed state','Check point in the undeformed state',...
'Check point in the deformed state'});
xlim([-0.4 0.4])
ylim([-0.4 0.4])
xlabel('x axis [m]');
ylabel('y axis[m]');

%%
%DISPLACEMENT FIELD
figure(2)
sz = 10;
subplot(1,2,1);
%plotting the absolute values of displacements%
scatter(coord(:,1), coord(:,2), sz, abs(disp(:,1)), 'filled');
xlabel('x');
ylabel('y');
title(['U11 in ', num2str(NumofDiv_x), ' * ', num2str(NumofDiv_y)]);
colorbar('southoutside');
colormap('jet');

subplot(1,2,2);
scatter(coord(:,1), coord(:,2), sz, abs(disp(:,2)), 'filled');
xlabel('x');
ylabel('y');
title(['U22 in ', num2str(NumofDiv_x), ' * ', num2str(NumofDiv_y)]);
colorbar('southoutside');
colormap('jet');
%%
%STRESS FIELD
figure(3)
sz = 10;
subplot(1,2,1);
scatter(coord(:,1), coord(:,2), sz, (Dongjun_hole_stress(:,1)), 'filled');
xlabel('x');
ylabel('y');
colorbar('southoutside');
colormap('jet');
title(['S11 in ', num2str(NumofDiv_x), ' * ', num2str(NumofDiv_y)]);
subplot(1,2,2);
scatter(coord(:,1), coord(:,2), sz, (Dongjun_hole_stress(:,2)), 'filled');
xlabel('x');
ylabel('y');
colorbar('southoutside');
colormap('jet');
title(['S22 in ', num2str(NumofDiv_x), ' * ', num2str(NumofDiv_y)]);
%%
%DONGJUN: STRESS vs NORMALIZED DISTANCE
figure(4)
subplot(1,2,1);
ssx = ExtractPathData(path_horizontal, Dongjun_hole_stress, 1);
plot(normal_path_horizontal, ssx);
xlabel('Material Points');
ylabel('S');
title('S11 in the horizontal edge');
subplot(1,2,2);
ssy = ExtractPathData(path_horizontal, Dongjun_hole_stress, 2);
plot(normal_path_horizontal, ssy);
xlabel('Material Points');
ylabel('S');
title('S22 in the horizontal edge');
%%
%DONGJUN: STRESS vs MATERIAL POINTS
figure(5)
subplot(1,2,1);
plot(ExtractPathData(path_horizontal, Dongjun_hole_stress, 1));
xlabel('Material Points');
ylabel('S');
title('S11 in the horizontal edge');
subplot(1,2,2);
plot(ExtractPathData(path_horizontal, Dongjun_hole_stress, 2));
xlabel('Material Points');
ylabel('S');
title('S22 in the horizontal edge');
%%
%DISPLACEMENT vs MATERIAL POINTS
figure(6)
subplot(1,2,1);
plot(ExtractPathData(path_horizontal, disp, 1));
xlabel('Material Points');
ylabel('U');
title('U11 in the horizontal edge');
subplot(1,2,2);
plot(ExtractPathData(path_horizontal, disp, 2));
xlabel('Material Points');
ylabel('U');
title('U22 in the horizontal edge');

%%
%Test point Deformed vs Undeformed position
figure(7)
hold on
h1=plot(Check_time(:,1),Steady_check_x(:,1),'.k');
h2=plot(Check_time(:,1),Steady_check_y(:,1),'.g');
legend([h1 h2],{'Displacement of x direction at blue point','Displacement of y direction at blue point'});
ylim([-0.01 0.01])
title({'Steady state checking'});
xlabel('Time');
ylabel('Displacement [m]');
%%
function [PD_SED_distorsion, SurCorrFactor_distorsion, PD_SED_dilatation, SurCorrFactor_dilatation] = Calculate_SurCorrection(delta,VolCorr_radius,bcs,bcd,Volume,SED_analytical_distorsion,SED_analytical_dilatation,disp,TotalNumMatPoint,numfam,nodefam,pointfam,coord)

        PD_SED_distorsion = zeros(TotalNumMatPoint,1);
        SurCorrFactor_distorsion = zeros(TotalNumMatPoint,1);
        PD_SED_dilatation = zeros(TotalNumMatPoint,1);
        SurCorrFactor_dilatation = zeros(TotalNumMatPoint,1);
        
       for i = 1:TotalNumMatPoint
        for j = 1:numfam(i,1)
        cnode = nodefam(pointfam(i,1)+j-1,1);
        RelativePosition_Vector = sqrt((coord(cnode,1) - coord(i,1))^2 + (coord(cnode,2) - coord(i,2))^2);
        RelativeDisp_Vector=sqrt((coord(cnode,1)+disp(cnode,1)-coord(i,1)-disp(i,1))^2+(coord(cnode,2)+disp(cnode,2)-coord(i,2)-disp(i,2))^2);
        Stretch = (RelativeDisp_Vector - RelativePosition_Vector) / RelativePosition_Vector;
        AbsoluteValue_x_y = RelativeDisp_Vector * RelativePosition_Vector;
        Coeff_x = (coord(cnode,1) + disp(cnode,1) - coord(i,1) - disp(i,1)) * (coord(cnode,1) - coord(i,1));
        Coeff_y = (coord(cnode,2) + disp(cnode,2) - coord(i,2) - disp(i,2)) * (coord(cnode,2) - coord(i,2));
        Directional_cosine = (Coeff_x + Coeff_y) / AbsoluteValue_x_y;
            if (RelativePosition_Vector <= delta-VolCorr_radius)
            fac = 1;
            elseif (RelativePosition_Vector <= delta+VolCorr_radius)
            fac = (delta+VolCorr_radius-RelativePosition_Vector)/(2*VolCorr_radius);
            else
            fac = 0;
            end
        PD_SED_distorsion(i,1) = PD_SED_distorsion(i,1) + bcs*delta * (Stretch^2) * (RelativePosition_Vector) * Volume * fac;
        PD_SED_dilatation(i,1) = PD_SED_dilatation(i,1) +  bcd * delta * Stretch * Directional_cosine * Volume * fac;
        end
        SurCorrFactor_distorsion(i,1) = SED_analytical_distorsion / PD_SED_distorsion(i,1);
        SurCorrFactor_dilatation(i,1) = SED_analytical_dilatation / PD_SED_dilatation(i,1);
       end
end

function [sorted] = SortPath(p_name, list, coord)
    
    if (strcmp(p_name,'hor')) %Checks if p_name is equal to 'hor'
        corr_coord = zeros(length(list), 1); % Creat a list of zeros with the length of path(list) size.
        for i = 1: length(list)
            corr_coord(i,1) = coord(list(i), 1); %Derive the coordinates of all the points in the path into corr_coord
        end
    [~,sortIdx] = unique(corr_coord, 'last');
    sorted = list(sortIdx);
    elseif(strcmp(p_name, 'ver') || strcmp(p_name,'edge'))
        corr_coord = zeros(length(list), 1);
        for i = 1: length(list)
            corr_coord(i,1) = coord(list(i), 2);
        end
     [~,sortIdx] = unique(corr_coord);
     sorted = list(sortIdx);
    end
        
end
function [extracted_data] = ExtractPathData(path, data, direction)
    extracted_data = [];
    for i = 1:max(size(path))
        extracted_data(end+1) = data(path(i), direction);
    end
end

%%%The function below calculates the stresses in the x and y direction of
%%%any point on the plate and returns a stress array.
function [stress] = CalculateStressforPoint(coord,TotalNumMatPoint,numfam,nodefam, pointfam, thick)
    stress = zeros(TotalNumMatPoint, 2); %Predifining the size of the stress array to speed up the calculations.

    for i = 1: (TotalNumMatPoint)
        f_x = 0; %Sum of all forces in X direction
        f_y = 0; %Sum of all forces in Y direction
        satisfy_x = 0;
        satisfy_y = 0;
        point_x = coord(i,1); %% Extract coordinates of point i
        point_y = coord(i,2);
        for j = 1: TotalNumMatPoint %% Iterating every other material point for conditions
            if (coord(j,2) == point_y && coord(j,1) < point_x + thick / 2) %% coord(j,2) == point_y &&
                    satisfy_x = satisfy_x + 1;
                    for k = 1:numfam(j,1) %%Iterate for all the neighbors of point j that satisfy the conditions.
                        cnode = nodefam(pointfam(j,1)+k-1,1);
                        if (coord(cnode,1) > point_x + thick / 2) % Sum bondforce of the neighbors that satisfy this condition
                            f_x = f_x + nodefam(pointfam(j,1)+k-1, 2); %%% Requires Saving BondForce_x in nodefam(:,2)
                        end
                    end
            end
            %Same below for stress in y direction
            if (coord(j,1) == point_x && coord(j,2) < point_y + thick / 2) %%%%coord(j,1) == point_x &&
                    satisfy_y = satisfy_y + 1;
                    for k = 1:numfam(j,1) %%Iterate for all the neighbors of point j that satisfy the conditions.
                        cnode = nodefam(pointfam(j,1)+k-1,1);
                        if (coord(cnode,2) > point_y + thick / 2) % Sum bondforce of the neighbors that satisfy this condition
                            f_y = f_y + nodefam(pointfam(j,1)+k-1, 3); %%% Requires Saving BondForce_x in nodefam(:,2)
                        end
                    end
            end
            stress_x = f_x * thick;
            stress_y = f_y * thick;
        end
        %Saving the stress for point i before moving on to the next point
        %on the plate
        stress(i,1) = stress_x;
        stress(i,2) = stress_y;
    end
    satisfy_x
    satisfy_y
end
