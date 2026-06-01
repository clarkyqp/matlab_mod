extract_row_from_removed_indices();
function extract_row_from_removed_indices()
% 可视化读取 removed_indices.mat 中的一行（一个块）并保存到新文件
% 
% removed_indices 是由 freq_domain_notch 生成的 cell 数组，
% 每个元素是一个向量，记录该 FFT 块中被删除的频率点序号。
%
% 用法: 直接运行 extract_row_from_removed_indices()

% --- 1. 选择 .mat 文件 ---
[filename, pathname] = uigetfile('*.mat', '请选择 removed_indices.mat 文件');
if isequal(filename, 0)
    disp('用户取消选择');
    return;
end
fullpath = fullfile(pathname, filename);

% --- 2. 加载变量 ---
data = load(fullpath);
if ~isfield(data, 'removed_indices')
    errordlg('所选文件中不存在变量 removed_indices', '加载错误');
    return;
end
removed_indices = data.removed_indices;
numBlocks = length(removed_indices);

% --- 3. 选择行（块序号）---
prompt = {sprintf('共有 %d 个 FFT 块\n请输入要查看的块序号 (1 到 %d):', numBlocks, numBlocks)};
dlgtitle = '选择行';
dims = [1 35];
definput = {'1'};
answer = inputdlg(prompt, dlgtitle, dims, definput);
if isempty(answer)
    return;
end
rowIdx = round(str2double(answer{1}));
if isnan(rowIdx) || rowIdx < 1 || rowIdx > numBlocks
    errordlg('无效的块序号', '输入错误');
    return;
end

% --- 4. 获取该行的数据 ---
rowData = removed_indices{rowIdx};
if isempty(rowData)
    dataStr = '（该块没有删除任何频率点）';
else
    dataStr = mat2str(rowData);
end

% --- 5. 可视化显示数据 ---
% 创建新窗口
fig = uifigure('Name', sprintf('块 %d 的被删除频点', rowIdx), ...
               'Position', [300 300 500 300]);
% 文本区域
txtArea = uitextarea(fig, 'Value', {sprintf('块序号: %d\n被删除的频点索引 (1-based):\n%s', rowIdx, dataStr)}, ...
                     'Editable', 'off', 'Position', [20 150 460 120]);
% 提示标签
uilabel(fig, 'Text', '数据已显示在上方，可以选择保存', ...
        'Position', [20 100 460 30]);

% --- 6. 询问是否保存到新 .mat 文件 ---
btn = uibutton(fig, 'push', 'Text', '保存此行数据到 .mat 文件', ...
               'Position', [180 40 150 30], ...
               'ButtonPushedFcn', @(btn,event) saveRowData(rowData, rowIdx));

    function saveRowData(data, idx)
        % 子函数：保存数据
        [saveFile, savePath] = uiputfile('*.mat', '保存选中的数据为 .mat 文件', ...
                                         sprintf('block_%d_removed_indices.mat', idx));
        if isequal(saveFile, 0)
            return;
        end
        saveFull = fullfile(savePath, saveFile);
        % 将数据存入变量 selected_removed_indices
        selected_removed_indices = data;
        save(saveFull, 'selected_removed_indices');
        uialert(fig, sprintf('数据已保存至:\n%s', saveFull), '保存成功', 'Icon','success');
    end

% 注：窗口关闭时自动结束
end