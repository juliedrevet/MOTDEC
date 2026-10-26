function helper_plot_overall_bars(cfg)

if isfield(cfg,'HGT'),HGT = cfg.HGT;
else, HGT = 4 ;end
if isfield(cfg,'rgb'),rgb = cfg.rgb;
else, rgb = lines; end
if isfield(cfg,'rgb_dat'),rgb = cfg.rgb_dat;
else, rgb_dat = [0.5 0.5 0.5]; end
if isfield(cfg,'width'),wdth = cfg.width;
else, wdth = 0.7; end
if isfield(cfg,'pbar'),pbar = cfg.pbar;
else, pbar = 1 ;end
if isfield(cfg,'ylim'),yl = cfg.ylim;
else, yl = [0 1];end
if ~isfield(cfg,'ttest'),cfg.ttest = false;end
if ~isfield(cfg,'tail'),cfg.tail = 'both';end % t-test between the 2 bars: 'both', 'right' (bar 1 > bar 2) or 'left' (bar 1 < bar 2)
if ~isfield(cfg,'type'),cfg.type = 'vertical';end

switch cfg.type
    case 'vertical'
        ori = 'v';
    case 'horizontal'
        ori = 'h';
end    

if isfield(cfg,'x')&&(size(cfg.x,2)>size(rgb,1))
    rgb = cat(1,rgb,lines);
end

if isfield(cfg,'x')
    nmodel = size(cfg.x,2);
else
    return;
end

if isfield(cfg,'figname')
    figure('Color','white','Name',cfg.figname);
else    
    figure('Color','white');
end

if isfield(cfg,'xlabel'), xlb = cfg.xlabel;
else, xlb = 'Xlabel';end
if isfield(cfg,'ylabel'), ylb = cfg.ylabel;
else, ylb = 'Ylabel';end

if isfield(cfg,'labels'),labels = cfg.labels;
else, labels = cellfun(@(s)sprintf('Label%s',s),cellstr(num2str((1:nmodel)')),'UniformOutput',false);end

if isfield(cfg,'xticklabel'), xtlb = cfg.xticklabel;
else, xtlb = labels;end

if isfield(cfg,'xpos'), xpos = cfg.xpos;
else, xpos = 1:nmodel;end

hold on

if isfield(cfg,'x') && ~isfield(cfg,'xqt')
    x = cfg.x;
    if iscell(cfg.x)
        xavg = nan(1,nmodel);
        xerr = nan(1,nmodel);
        for imod = 1:nmodel
            xavg(imod) = mean(x{imod},'omitnan');
            xerr(imod) = std(x{imod},0,1,'omitnan')/sqrt(numel(x{imod}));
        end
    else
        ndata = size(x,1);
        xavg = mean(x,1,'omitnan');
        xerr = std(x,0,1,'omitnan')/sqrt(ndata);
    end
    if isfield(cfg,'pbar'),pbar = cfg.pbar;
    else, pbar = (nmodel+1.2)/HGT ;end
    if isfield(cfg,'xlim')
        xl = cfg.xlim;
    else
        xl = [.4,nmodel+.6];
    end
    switch ori
        case 'v'
            xlim(xl);
            ylim(yl);
        case 'h'
            ylim(xl);
            xlim(yl);
    end
    for i = 1:nmodel
        switch ori
            case 'v'
                bar(xpos(i),xavg(i),wdth,'EdgeColor',rgb(i,:),'FaceColor',0.5*(rgb(i,:)+1),'LineWidth',1);
            case 'h'
                barh(xpos(i),xavg(i),wdth,'EdgeColor',rgb(i,:),'FaceColor',0.5*(rgb(i,:)+1),'LineWidth',1);
        end
        
    end
    switch ori
        case 'v'
            if nmodel == 1
                set(gca,'XTick',xpos,'XTickLabel',xtlb)
            else
                set(gca,'XTick',xpos,'XTickLabel',xtlb(1:nmodel))
            end
        case 'h'
            if nmodel == 1
                set(gca,'YTick',xpos,'YTickLabel',xtlb)
            else
                set(gca,'YTick',xpos,'YTickLabel',xtlb(1:nmodel))
            end
    end
        
end


if isfield(cfg,'x') && isfield(cfg,'xqt')
    x = cfg.x;
    xqt = cfg.xqt;
    xavg = mean(x,1,'omitnan');
    
    if isfield(cfg,'pbar'),pbar = cfg.pbar;
    else, pbar = (nmodel+1.2)/HGT ;end
    if isfield(cfg,'xlim')
        xl = cfg.xlim;
    else
        xl = [.4,nmodel+.6];
    end
    switch ori
        case 'v'
            xlim(xl);
            ylim(yl);
        case 'h'
            ylim(xl);
            xlim(yl);
    end
    for i = 1:nmodel
        switch ori
            case 'v'
                bar(xpos(i),xavg(i),wdth,'EdgeColor',rgb(i,:),'FaceColor',0.5*(rgb(i,:)+1),'LineWidth',1);
                plot(xpos(i)*[1,1],[xqt(i,1),xqt(i,2)],'Color','k','LineWidth',0.75);
            case 'h'
                barh(xpos(i),xavg(i),wdth,'EdgeColor',rgb(i,:),'FaceColor',0.5*(rgb(i,:)+1),'LineWidth',1);
                plot([xqt(i,1),xqt(i,2)],i*[1,1],'Color','k','LineWidth',0.75);
        end   
    end
    switch ori
        case 'v'
            set(gca,'XTick',xpos,'XTickLabel',xtlb(1:nmodel))
        case 'h'
            set(gca,'YTick',xpos,'YTickLabel',xtlb(1:nmodel))
    end
        
end


if isfield(cfg,'x') && cfg.ttest
    x = cfg.x;
    nmodel = size(x,2);
    if nmodel == 2
        if iscell(cfg.x)
            [H,P] = ttest2(x{1},x{2},'Tail',cfg.tail);
        else
            [H,P] = ttest(x(:,1),x(:,2),'Tail',cfg.tail);
        end
        if P < .001
            ptxt = 'p < 0.001';
        else
            ptxt = sprintf('p = %.3f',P);
        end
        switch ori
            case 'v'
                line([1 2],min(ylim)+.9*diff(ylim)*[1 1],'Color','k')
                if H == 0
                    text(1.5,min(ylim)+.95*diff(ylim),ptxt,'HorizontalAlignment','center')
                else
                    if P<=.001
                        text(1.5-.1,min(ylim)+.95*diff(ylim),'***')
                    elseif P<=.01
                        text(1.5-.05,min(ylim)+.95*diff(ylim),'**')
                    elseif P<=.05
                        text(1.5-.01,min(ylim)+.95*diff(ylim),'*')
                    end
                end
            case 'h'
                line(.9*max(xlim)*[1 1],[1 2],'Color','k')
                if H == 0
                    text(min(xlim)+.95*diff(xlim),1.5,ptxt)
                else
                    if P<=.001
                        text(min(xlim)+.95*diff(xlim),1.5-.1,'***')
                    elseif P<=.01
                        text(min(xlim)+.95*diff(xlim),1.5-.05,'**')
                    elseif P<=.05
                        text(min(xlim)+.95*diff(xlim),1.5-.01,'*')
                    end
                end
        end
    end
end

if isfield(cfg,'x') && isfield(cfg,'plotx') && cfg.plotx
    nmodel = size(cfg.x,2);
    for imod = 1:nmodel
        if iscell(cfg.x)
            x = cfg.x{imod};
        else
            x = cfg.x(:,imod);
        end
        wid = 0.1;
        xk = linspace(min(x),max(x),100);
        [pk,~,u] = ksdensity(x,xk);
        while true
            z = findpeaks(pk,xk);
            if numel(z) <= 1
                break
            else
                u = u*1.1;
                pk = ksdensity(x,xk,'BandWidth',u);
            end
        end
        pk = pk/max(pk);
        str = interp1(xk,pk,x);
        jit = linspace(-1,+1,numel(x));
        for i = 1:numel(x)
            switch ori
                case 'v'
                    plot(xpos(imod)+jit(i)*str(i)*wid,x(i),'o','MarkerFaceColor',.5*(rgb(imod,:)+1),'MarkerSize',3,'MarkerEdgeColor','w');
                case 'h'
                    plot(x(i),xpos(imod)+jit(i)*str(i)*wid,'o','MarkerFaceColor',.5*(rgb(imod,:)+1),'MarkerSize',3,'MarkerEdgeColor','w');
            end
        end
    end
    
end

% add error bars after plotx
if isfield(cfg,'x') && ~isfield(cfg,'xqt') 
    x = cfg.x;
    if iscell(cfg.x)
        xavg = nan(1,nmodel);
        xerr = nan(1,nmodel);
        for imod = 1:nmodel
            xavg(imod) = mean(x{imod},'omitnan');
            xerr(imod) = std(x{imod},0,1,'omitnan')/sqrt(numel(x{imod}));
        end
    else
        ndata = size(x,1);
        xavg = mean(x,1,'omitnan');
        xerr = std(x,0,1,'omitnan')/sqrt(ndata);
    end
    for i = 1:nmodel
        switch ori
            case 'v'
                plot(xpos(i)*[1,1],xavg(i)+xerr(i)*[-1,+1],'k-','LineWidth',0.75);
            case 'h'
                plot(xavg(i)+xerr(i)*[-1,+1],i*[1,1],'k-','LineWidth',0.75);
        end
        
    end
        
end


if isfield(cfg,'xdat')
    x = cfg.xdat;
    xavg = mean(x,1,'omitnan');
    xstd = std(x,0,1,'omitnan');
    npos = size(x,2);
    if isfield(cfg,'pos_dat')
        pos = cfg.pos_dat;
        if numel(pos)~=npos
            error('data position does not match data size!')
        end
    else
        switch ori
            case 'v'
                npt = diff(xlim)/(npos+1);
                pos = min(xlim):npt:max(xlim);
            case 'h'
                npt = diff(ylim)/(npos+1);
                pos = min(ylim):npt:max(ylim);
        end
        pos = pos(2:(end-1));
    end
    wid = 0.1;
    for ipos = 1:npos
        xk = linspace(min(x(:,ipos)),max(x(:,ipos)),100);
        [pk,~,u] = ksdensity(x(:,ipos),xk);
        while true
            z = findpeaks(pk,xk);
            if numel(z) <= 1
                break
            else
                u = u*1.1;
                pk = ksdensity(x(:,ipos),xk,'BandWidth',u);
            end
        end
        pk = pk/max(pk);
        str = interp1(xk,pk,x(:,ipos));
        jit = linspace(-1,+1,numel(x(:,ipos)));
        for i = 1:numel(x(:,ipos))
            switch ori
                case 'v'
                    plot(pos(ipos)+jit(i)*str(i)*wid,x(i,ipos),'o','MarkerFaceColor',.5*(rgb_dat+1),'MarkerSize',3,'MarkerEdgeColor','w');
                case 'h'
                    plot(x(i,ipos),pos(ipos)+jit(i)*str(i)*wid,'o','MarkerFaceColor',.5*(rgb_dat+1),'MarkerSize',3,'MarkerEdgeColor','w');
            end
        end
        switch ori
            case 'v'
                plot([pos(ipos) pos(ipos)],xavg(ipos)+xstd(ipos)*[-1,+1],'k-');
                plot(pos(ipos),xavg(ipos),'ko','MarkerSize',4.5,'MarkerFaceColor',rgb_dat);
            case 'h'
                plot(xavg(ipos)+xstd(ipos)*[-1,+1],[pos(ipos) pos(ipos)],'k-');
                plot(xavg(ipos),pos(ipos),'ko','MarkerSize',4.5,'MarkerFaceColor',rgb_dat);
        end
    end
end

if isfield(cfg,'x') && isfield(cfg,'xdat') && cfg.ttest
    x = cfg.x;
    nmodel = size(x,2);
    xdat = cfg.xdat;
    for i = 1:nmodel
        [H,P,~,~] = ttest(xdat,x(:,i));
        ptxt = sprintf('p = %.3f',P);
        if H == 0
            switch ori
                case 'v'
                    text(i,min(ylim)+.9*diff(ylim),ptxt,'HorizontalAlignment','center')
                case 'h'
                    text(min(xlim)+.9*diff(xlim),i,ptxt)
            end
        else
            switch ori
                case 'v'
                    if P<=.001
                        text(i-.1,min(ylim)+.9*diff(ylim),'***')
                    elseif P<=.01
                        text(i-.05,min(ylim)+.9*diff(ylim),'**')
                    elseif P<=.05
                        text(i-.01,min(ylim)+.9*diff(ylim),'*')
                    end
                case 'h'
                    if P<=.001
                        text(min(xlim)+.9*diff(xlim),i-.1,'***')
                    elseif P<=.01
                        text(min(xlim)+.9*diff(xlim),i-.05,'**')
                    elseif P<=.05
                        text(min(xlim)+.9*diff(xlim),i-.01,'*')
                    end
            end
        end
    end
end

if isfield(cfg,'ytick')
    switch ori
        case 'v'
            set(gca,'YTick',cfg.ytick);
        case 'h'
            set(gca,'XTick',cfg.ytick);
    end
end
if isfield(cfg,'yticklabel')
    switch ori
        case 'v'
            set(gca,'YTickLabel',cfg.yticklabel);
        case 'h'
            set(gca,'XTickLabel',cfg.yticklabel);
    end
end
switch ori
    case 'v'
        xlabel(xlb); ylabel(ylb);
    case 'h'
        ylabel(xlb); xlabel(ylb);
end
set(gca,'XTickLabelRotation', 0)
if isfield(cfg,'title')
    title(cfg.title);
end
if isfield(cfg,'figILL') && cfg.figILL || ~isfield(cfg,'figILL')
    fig = helper_ILL(gcf,pbar,HGT,false);
    set(fig,'PaperPositionMode','manual', ...
        'PaperPosition',[2.5,13,16,HGT],'PaperUnits','centimeters', ...
        'PaperType','A4','PaperOrientation','portrait');
end
if isfield(cfg,'saveornot') && isfield(cfg,'figname') && isfield(cfg,'figpath')
    if cfg.saveornot
        print(fullfile(cfg.figpath,cfg.figname),'-vector','-dpdf');
        fprintf('\nfigure %s saved in %s !\n',cfg.figname,cfg.figpath)
    end
end
    
end