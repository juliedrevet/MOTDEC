function f = helper_ILL(f,pbar,h,mkr_onoff,alpha_onoff)

if nargin < 2
    pbar = 1;
end
if nargin < 3
    h = 5;
end
if nargin < 4
    mkr_onoff = true;
end
if nargin < 5
    alpha_onoff = true;
end
% 4th argument: false = markers left as they are, true = default size, or a number = size of the 'o' markers
if islogical(mkr_onoff)
    if h < 5
        mkr_siz = 4.5;
    else
        mkr_siz = 5;
    end
else
    mkr_siz = mkr_onoff;
    mkr_onoff = true;
end

set(f,'units','centimeters','innerposition',[0 0 16 h]);

txt_siz = 7.2;
fnt_siz = 8;


% change all axes from figure f to color black
axes = findobj(f, 'type', 'axes');
for a = 1:length(axes)
    axes(a).YColor = [0 0 0];
    axes(a).XColor = [0 0 0];
end


% access Axes children
axes = findobj(f, 'type', 'axes');
for a = 1:length(axes)
    for ic = 1:numel(axes(a).Children)
        % annotation Fontsize and FontName
        if strcmp(axes(a).Children(ic).Type,'text')
            axes(a).Children(ic).FontSize = txt_siz;
            axes(a).Children(ic).FontName = 'Helvetica';
        end
        if mkr_onoff && isprop(axes(a).Children(ic),'Marker') && strcmp(axes(a).Children(ic).Marker,'o')
            if isprop(axes(a).Children(ic),'SizeData') % scatter
                axes(a).Children(ic).SizeData = mkr_siz*10;
            else
                axes(a).Children(ic).MarkerSize = mkr_siz;
            end
        end
        if ~alpha_onoff
            % remove alpha transparency
            try    axes(a).Children(ic).FaceAlpha = 1; % for patch or fill
            catch;end
            try    axes(a).Children(ic).MarkerFaceAlpha = 1; % for scatter
            catch;end
            try    axes(a).Children(ic).MarkerEdgeAlpha = 1; % for scatter
            catch;end
        end
    end
    try axes(a).Legend.FontSize = txt_siz;catch;end
end

 xtickangle(0)

% change general font, plotboxaspectratio, etc...
axes = findobj(f, 'type', 'axes');
for a = 1:length(axes)
    set(axes(a),'Layer','top','Box','off','PlotBoxAspectRatio',[pbar,1,1]);
    set(axes(a),'TickDir','out','TickLength',[1,1]*0.02/max(pbar,1));
    set(axes(a),'FontName','Helvetica','FontSize',txt_siz);
    axes(a).XLabel.FontSize = fnt_siz;
    axes(a).YLabel.FontSize = fnt_siz;
end

% NEW FROM 2023 ON: change all axes width to 0.75
axes = findobj(f, 'type', 'axes');
for a = 1:length(axes)
    axes(a).LineWidth=0.75;
end

set(f,'units','centimeters','innerposition',[0 0 16 h]);
set(f,'PaperPositionMode','manual', ...
            'PaperPosition',[2.5,13,16,h],'PaperUnits','centimeters', ...
            'PaperType','A4','PaperOrientation','portrait');
end