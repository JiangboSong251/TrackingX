% Plot settings
ShowPlots = 0;
SkipSimFrames = 10;
ShowUpdate = 0;
ShowArena = 0;
ShowPredict = 0;
SimNum = 50000;
V_bounds = [0 250 0 70];

% Recording Settings
Record = 0;
clear Frames
clear M

% Instantiate a Tracklist to store each filter
FilterList = [];
FilterNum = 1;

% Containers
Logs = cell(1, 3); % 4 tracks
N = size(x_true,1);
for i=1:FilterNum
    Logs{i}.xV = zeros(4,N);          %estmate        % allocate memory
    Logs{i}.err = zeros(2,N);
    Logs{i}.pos_err = zeros(1,N);
    Logs{i}.exec_time = 0;
    Logs{i}.filtered_estimates = cell(1,N);
end

% Create figure windows
if(ShowPlots)
    if(ShowArena)
        img = imread('maze.png');

        % set the range of the axes
        % The image will be stretched to this.
        min_x = 0;
        max_x = 10;
        min_y = 0;
        max_y = 10;

        % make data to plot - just a line.
        x = min_x:max_x;
        y = (6/8)*x;
    end
    
    figure('units','normalized','outerposition',[0 0 1 1])
    ax(1) = gca;
end
Params_dyn.xDim = 1;
Params_dyn.q = 0.1;
DynModel = GenericDynamicModelX(Params_dyn);
DynModel.Params.F = @(~) 1;
Params_obs.xDim = 1;
Params_obs.yDim = 1;
Params_obs.r = 20;
DynModel = GenericDynamicModelX(Params_dyn);
ObsModel = PositionalObsModelX(Params_obs);%GenericObservationModelX(Params_obs);
%ObsModel.Params.H = @(~) [1 0 0 0; 0 1 0 0];
% Constant Velocity Model
DynModel = ConstantVelocityModelX(Params_dyn);
Q_old = DynModel.Params.Q(1);
F_old = DynModel.Params.F(1);
% % Positional Observation Model;
% obs_model = PositionalObsModelX('xDim',4,'yDim',2,'r',0.1,'smartArgs', false);

% Generate ground truth and measurements
for k = 1:N
    % Generate new measurement from ground truth
    sV(:,k) = [x_true(k,1); y_true(k,1)];     % save ground truth
    zV(:,k) = ObsModel.sample(0, sV(:,k),1);     % generate noisy measurment
end

%ObsModel.Params.H = @(~) [1 0 1 1; 0 1 1 1];
%ObsModel.Params.R = @(~) ObsModel.Params.R(1)*1000;
DynModel.Params.Q = @(~) eye(4);

FilterList = cell(1,FilterNum);    
% Initiate Kalman Filter
Params_kf.k = 1;
Params_kf.x_init = [x_true(2,1); y_true(2,1); x_true(2,1)-x_true(1,1); y_true(2,1)-y_true(1,1)];
Params_kf.P_init = DynModel.Params.Q(1);
Params_kf.DynModel = DynModel;
Params_kf.ObsModel = ObsModel;


FilterList{1}.Filter = KalmanFilterX(Params_kf);
%FilterList{1}.Filter.DynModel.Params.F = @(~)F;
%FilterList{1}.Filter.DynModel.Params.Q = @(~)Q;
%FilterList{1}.Filter.ObsModel.Params.R = @(~)R;
for SimIter = 1:SimNum
    fprintf('\nSimIter: %d/%d\n', SimIter, SimNum);

    % FILTERING
    % ===================>
    tic;
    for k = 1:N
        
        % Update measurements
        for i=1:FilterNum
            FilterList{i}.Filter.Params.y = zV(:,k);
        end

        % Iterate all filters
        for i=1:FilterNum
            tic;
            FilterList{i}.Filter.Iterate();
            Logs{i}.exec_time = Logs{i}.exec_time + toc;
        end

        % Store Logs
        for i=1:FilterNum
            Logs{i}.err(:,k) = Logs{i}.err(:,k) + (sV(:,k) - FilterList{i}.Filter.Params.x(1:2))/SimNum;
            Logs{i}.pos_err(1,k) = Logs{i}.pos_err(1,k) + (sV(1,k) - FilterList{i}.Filter.Params.x(1))^2 + (sV(2,k) - FilterList{i}.Filter.Params.x(2))^2;
            Logs{i}.xV(:,k) = FilterList{i}.Filter.Params.x;
            Logs{i}.filtered_estimates{k} = FilterList{i}.Filter.Params;
        end

      % Plot update step results
        if(ShowPlots && ShowUpdate)
            % Plot data
            cla(ax(1));

            if(ShowArena)
                 % Flip the image upside down before showing it
                imagesc(ax(1),[min_x max_x], [min_y max_y], flipud(img));
            end

            % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
            hold on;
            h2 = plot(ax(1),zV(1,k),zV(2,k),'k*','MarkerSize', 10);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
            h2 = plot(ax(1),sV(1,1:k),sV(2,1:k),'b.-','LineWidth',1);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
            h2 = plot(ax(1),sV(1,k),sV(2,k),'bo','MarkerSize', 10);
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend

            for i=1:FilterNum
                h2 = plot(Logs{i}.xV(1,k), Logs{i}.xV(2,k), 'o', 'MarkerSize', 10);
                set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
                %plot(pf.Params.particles(1,:), pf.Params.particles(2,:), 'b.', 'MarkerSize', 10);
                plot(Logs{i}.xV(1,1:k), Logs{i}.xV(2,1:k), '.-', 'MarkerSize', 10);
            end
            legend('KF','EKF', 'UKF', 'PF', 'EPF', 'UPF')

            if(ShowArena)
                % set the y-axis back to normal.
                set(ax(1),'ydir','normal');
            end

            str = sprintf('Robot positions (Update)');
            title(ax(1),str)
            xlabel('X position (m)')
            ylabel('Y position (m)')
            axis(ax(1),V_bounds)
            pause(0.01);
        end
      %s = f(s) + q*randn(3,1);                % update process 
    end
    
    filtered_estimates = Logs{1}.filtered_estimates;
    
    % SMOOTHING
    % ===================>
    smoothed_estimates = FilterList{i}.Filter.Smooth(filtered_estimates);
    xV_smooth = zeros(4,N);
    PV_smooth = zeros(4,4,N);
    for i=1:N
        xV_smooth(:,i) = smoothed_estimates{i}.x;          %estmate        % allocate memory
        PV_smooth(:,:,i) = smoothed_estimates{i}.P;
    end
    if(Record || (ShowPlots && (SimIter==1 || rem(SimIter,SkipSimFrames)==0)))
        
        ax(1) = gca;
        % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
        % Flip the image upside down before showing it
        % Plot data
        cla(ax(1));
         % Flip the image upside down before showing it

        % NOTE: if your image is RGB, you should use flipdim(img, 1) instead of flipud.
        hold on;
        h2 = plot(ax(1),zV(1,1:k),zV(2,1:k),'k*','MarkerSize', 10);
        h2 = plot(ax(1),sV(1,1:k),sV(2,1:k),'b.-','LineWidth',1);
        if j==2
            set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        end
        h2 = plot(ax(1),sV(1,k),sV(2,k),'bo','MarkerSize', 10);
        set(get(get(h2,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % Exclude line from legend
        plot(Logs{1}.xV(1,k), Logs{1}.xV(2,k), 'ro', 'MarkerSize', 10);
        plot(Logs{1}.xV(1,1:k), Logs{1}.xV(2,1:k), 'r.-', 'MarkerSize', 10);
        plot(xV_smooth(1,k), xV_smooth(2,k), 'go', 'MarkerSize', 10);
        plot(xV_smooth(1,1:k), xV_smooth(2,1:k), 'g.-', 'MarkerSize', 10);
        for ki = 1:k
            plot_gaussian_ellipsoid(xV_smooth(1:2,ki), PV_smooth(1:2,1:2,ki), 1, [], ax(1));
        end
        % set the y-axis back to normal.
        set(ax(1),'ydir','normal');
        str = sprintf('Robot positions (Update)');
        title(ax(1),str)
        xlabel('X position (m)')
        ylabel('Y position (m)')
        %axis(ax(1),V_bounds)
        pause(.01);
        
        if(Record)
            Frames(SimIter) = getframe(ax(1));
        end
    end
    xV_filt = cell2mat(cellfun(@(x)x.x,filtered_estimates,'un',0)); 
    meanRMSE_filt   = mean(abs((xV_filt(1,:).^2+xV_filt(2,:).^2).^0.5 - (x_true.^2 + y_true.^2)'.^0.5))
    meanRMSE_smooth = mean(abs((xV_smooth(1,:).^2+xV_smooth(2,:).^2).^0.5 - (x_true.^2 + y_true.^2)'.^0.5))
    
    [F,Q,H,R] = KalmanFilterX_LearnEM_Mstep(filtered_estimates, smoothed_estimates,FilterList{1}.Filter.DynModel.sys(),FilterList{1}.Filter.ObsModel.obs());
    
    % Reset KF
    F = F
    Q = Q
    R = R
    FilterList{1}.Filter = KalmanFilterX(Params_kf);
    %FilterList{1}.Filter.DynModel.Params.F = @(~)F;
    FilterList{1}.Filter.DynModel.Params.Q = @(~) Q;
    %FilterList{1}.Filter.ObsModel.Params.H = @(~)H;
    %FilterList{1}.Filter.ObsModel.Params.R = @(~) R; %diag(diag(R));
    
end

% figure
% for i=1:FilterNum
%     hold on;
%     plot(sqrt(Logs{i}.pos_err(1,:)/SimNum), '.-');
% end
% legend('KF','EKF', 'UKF', 'PF', 'EPF', 'UPF');%, 'EPF', 'UPF')

% figure
% bars = zeros(1, FilterNum);
% c = {'KF','EKF', 'UKF', 'PF', 'EPF', 'UPF'};
% c = categorical(c, {'KF','EKF', 'UKF', 'PF', 'EPF', 'UPF'},'Ordinal',true); %, 'EPF', 'UPF'
% for i=1:FilterNum
%     bars(i) =  Logs{i}.exec_time;
% end
% bar(c, bars);
%smoothed_estimates = pf.Smooth(filtered_estimates);
% toc;
% END OF SIMULATION
% ===================>

if(Record)
    Frames = Frames(2:end);
    vidObj = VideoWriter(sprintf('em_test.avi'));
    vidObj.Quality = 100;
    vidObj.FrameRate = 100;
    open(vidObj);
    writeVideo(vidObj, Frames);
    close(vidObj);
end
