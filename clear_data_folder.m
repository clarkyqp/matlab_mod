removeFilesUI();
function removeFilesUI()
% removeFilesUI 图形界面：删除文件夹下所有文件（不删除文件夹）
%   提供文件夹选择、递归选项、关键词筛选（包含任一关键词即删除）、执行和状态反馈。

    % 创建主窗口（高度保持 280）
    fig = uifigure('Name', '批量删除文件工具', 'Position', [300 300 500 280], ...
                   'Resize', 'off');
    
    % 文件夹选择区域
    uilabel(fig, 'Position', [20 210 80 22], 'Text', '目标文件夹:', ...
            'FontWeight', 'bold');
    folderField = uieditfield(fig, 'text', 'Position', [100 210 280 22], ...
                              'Editable', 'off');
    browseBtn = uibutton(fig, 'push', 'Position', [390 210 90 22], ...
                         'Text', '浏览...', 'ButtonPushedFcn', @(btn,event) browseFolder());
    
    % 文件筛选区域（关键词输入）
    uilabel(fig, 'Position', [20 180 80 22], 'Text', '筛选关键词:', ...
            'FontWeight', 'bold');
    filterField = uieditfield(fig, 'text', 'Position', [100 180 280 22], ...
                              'Tooltip', '多个关键词用空格分隔，文件名包含任一关键词即删除（不区分大小写）');
    % 提示示例
    uilabel(fig, 'Position', [100 160 380 18], 'Text', '例：temp log 2024  将删除文件名包含 temp、log 或 2024 的文件', ...
            'FontColor', [0.5 0.5 0.5], 'FontSize', 10);
    
    % 递归选项（复选框）
    recursiveCheck = uicheckbox(fig, 'Position', [20 130 280 22], ...
                                'Text', '递归删除子文件夹中的文件（默认）', ...
                                'Value', true);
    
    % 提示标签
    uilabel(fig, 'Position', [20 100 460 30], ...
            'Text', '注意：仅删除文件，所有文件夹（包括空文件夹）将被保留。关键词为空时删除所有文件。', ...
            'FontColor', [0.5 0.5 0.5], 'FontSize', 10);
    
    % 执行按钮
    execBtn = uibutton(fig, 'push', 'Position', [150 50 200 30], ...
                       'Text', '开始删除文件', ...
                       'ButtonPushedFcn', @(btn,event) executeDeletion(), ...
                       'BackgroundColor', [0.9 0.3 0.2], 'FontColor', 'w', ...
                       'FontWeight', 'bold');
    
    % 状态栏
    statusLabel = uilabel(fig, 'Position', [20 20 460 22], ...
                          'Text', '就绪', ...
                          'FontAngle', 'italic');
    
    % 存储选择的文件夹路径
    selectedFolder = '';
    
    % 解析关键词字符串，返回关键词元胞数组（自动去除空格和空串）
    function keywords = parseKeywords(inputStr)
        keywords = {};
        if isempty(strtrim(inputStr))
            return;
        end
        parts = strsplit(strtrim(inputStr));
        % 移除空串（如连续空格导致）
        parts = parts(~cellfun(@isempty, parts));
        keywords = parts;  % 直接作为子串即可
    end
    
    % 检查文件名是否包含任一关键词（不区分大小写）
    function match = matchesAnyKeyword(filename, keywords)
        match = false;
        if isempty(keywords)
            match = true;   % 无关键词则匹配所有
            return;
        end
        lowerFilename = lower(filename);
        for i = 1:length(keywords)
            if contains(lowerFilename, lower(keywords{i}))
                match = true;
                break;
            end
        end
    end
    
    % 浏览文件夹的回调
    function browseFolder()
        folder = uigetdir('', '请选择要清理的文件夹');
        if ischar(folder) && ~isequal(folder, 0)
            selectedFolder = folder;
            folderField.Value = selectedFolder;
            statusLabel.Text = sprintf('已选择: %s', selectedFolder);
            statusLabel.FontColor = [0 0 0];
        else
            statusLabel.Text = '未选择文件夹';
            statusLabel.FontColor = [0.8 0 0];
        end
    end
    
    % 执行删除的回调
    function executeDeletion()
        % 检查是否已选择文件夹
        if isempty(selectedFolder) || ~isfolder(selectedFolder)
            uialert(fig, '请先选择一个有效的文件夹。', '无效路径', 'Icon', 'warning');
            return;
        end
        
        % 获取递归选项
        recursive = recursiveCheck.Value;
        
        % 获取关键词
        keywords = parseKeywords(filterField.Value);
        
        % 构建确认消息
        if recursive
            msgPath = sprintf('文件夹 "%s" 及其所有子文件夹中', selectedFolder);
        else
            msgPath = sprintf('文件夹 "%s" 中（仅顶层）', selectedFolder);
        end
        if isempty(keywords)
            msgCond = '的全部文件';
        else
            keywordsStr = strjoin(keywords, '、');
            msgCond = sprintf('文件名包含 %s 中任一关键词的文件', keywordsStr);
        end
        msgConfirm = sprintf('确认要删除 %s 的%s吗？\n注意：文件夹本身不会被删除。', msgPath, msgCond);
        choice = uiconfirm(fig, msgConfirm, '确认删除', ...
                           'Options', {'确认删除', '取消'}, ...
                           'DefaultOption', 2, 'CancelOption', 2);
        if ~strcmp(choice, '确认删除')
            statusLabel.Text = '操作已取消';
            statusLabel.FontColor = [0.8 0.5 0];
            return;
        end
        
        % 开始删除，禁用按钮避免重复点击
        execBtn.Enable = 'off';
        statusLabel.Text = '正在删除文件，请稍候...';
        statusLabel.FontColor = [0 0.5 0.8];
        drawnow;
        
        % 统计删除的文件数量
        fileCount = 0;
        try
            if recursive
                fileCount = deleteAllFilesRecursive(selectedFolder, keywords);
            else
                fileCount = deleteTopLevelFiles(selectedFolder, keywords);
            end
            if isempty(keywords)
                statusLabel.Text = sprintf('完成！共删除 %d 个文件。', fileCount);
            else
                statusLabel.Text = sprintf('完成！共删除 %d 个匹配关键词的文件。', fileCount);
            end
            statusLabel.FontColor = [0 0.6 0];
        catch ME
            statusLabel.Text = sprintf('错误: %s', ME.message);
            statusLabel.FontColor = [0.8 0 0];
            uialert(fig, ME.message, '删除失败', 'Icon', 'error');
        end
        
        execBtn.Enable = 'on';
    end
    
    % 仅删除顶层文件（不递归）
    function count = deleteTopLevelFiles(folder, keywords)
        count = 0;
        items = dir(folder);
        for i = 1:length(items)
            if items(i).isdir
                continue;  % 跳过所有文件夹
            end
            if strcmp(items(i).name, '.') || strcmp(items(i).name, '..')
                continue;
            end
            % 检查文件名是否包含任一关键词
            if ~matchesAnyKeyword(items(i).name, keywords)
                continue;
            end
            fullPath = fullfile(folder, items(i).name);
            delete(fullPath);
            count = count + 1;
        end
    end
    
    % 递归删除所有文件（保留文件夹结构）
    function total = deleteAllFilesRecursive(folder, keywords)
        total = 0;
        items = dir(folder);
        for i = 1:length(items)
            name = items(i).name;
            if strcmp(name, '.') || strcmp(name, '..')
                continue;
            end
            fullPath = fullfile(folder, name);
            if items(i).isdir
                % 递归进入子文件夹
                total = total + deleteAllFilesRecursive(fullPath, keywords);
            else
                % 检查文件名是否包含任一关键词
                if ~matchesAnyKeyword(name, keywords)
                    continue;
                end
                delete(fullPath);
                total = total + 1;
            end
        end
    end
end