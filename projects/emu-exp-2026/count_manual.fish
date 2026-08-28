#!/usr/bin/env fish

# 手册目录（默认为当前目录，也可通过参数传入）
set TARGET_DIR (test (count $argv) -gt 0; and echo $argv[1]; or echo (status dirname))

set total_lines 0
set total_chars 0
set total_words 0

echo "=========================================================================="
printf "%-18s %10s %12s %10s %10s\n" "文档名称" "行数 (Lines)" "字数 (Chars)" "词数 (Words)" "文件大小"
echo "--------------------------------------------------------------------------"

# 按文件名自然排序获取所有 md 文件
for file in (path sort (find $TARGET_DIR -maxdepth 1 -name "*.md"))
    set filename (path basename $file)
    
    # 统计行数、字符数 (Unicode 字数)、词数
    set lines (wc -l < $file | string trim)
    set chars (wc -m < $file | string trim)
    set words (wc -w < $file | string trim)
    set size (ls -lh $file | awk '{print $5}')
    
    set total_lines (math "$total_lines + $lines")
    set total_chars (math "$total_chars + $chars")
    set total_words (math "$total_words + $words")
    
    printf "%-18s %10d %12d %10d %10s\n" $filename $lines $chars $words $size
end

echo "=========================================================================="
printf "%-18s %10d %12d %10d\n" "总计 (Total)" $total_lines $total_chars $total_words
echo "=========================================================================="
