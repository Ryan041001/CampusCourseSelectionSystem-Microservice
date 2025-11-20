#!/usr/bin/env python3
"""
自动为 test-all-apis.sh 添加详细的 API 请求日志
"""
import re
import sys

def add_request_logging(content):
    """为每个测试用例添加 print_request 调用"""
    
    # 模式1: POST/PUT/DELETE 请求（带请求体）
    pattern1 = r'(# TC-[A-Z]+-\d+:.*?\necho ">>> TC-[A-Z]+-\d+:.*?"\n)(RESPONSE=\$\(curl -s -w "\\n%\{http_code\}" -X (POST|PUT|DELETE) (\$BASE_URL_[A-Z]+/[^\s\\]+)[^\)]+\n-H "Content-Type: application/json" \\\n-d \'([^\']+)\')'
    
    def replace_with_body(match):
        header = match.group(1)
        method = match.group(3)
        url = match.group(4)
        body = match.group(5)
        
        # 提取请求体并存储为变量
        result = header
        result += f'REQUEST_DATA=\'{body}\'\n'
        result += f'print_request "{method}" "{url}" "$REQUEST_DATA"\n'
        result += match.group(2).replace(f"'{body}'", '"$REQUEST_DATA"')
        return result
    
    content = re.sub(pattern1, replace_with_body, content, flags=re.MULTILINE | re.DOTALL)
    
    # 模式2: GET 请求（无请求体）
    pattern2 = r'(# TC-[A-Z]+-\d+:.*?\necho ">>> TC-[A-Z]+-\d+:.*?"\n)(RESPONSE=\$\(curl -s -w "\\n%\{http_code\}" (?:-X GET )?(\$BASE_URL_[A-Z]+/[^\s\)]+))'
    
    def replace_without_body(match):
        header = match.group(1)
        url = match.group(3)
        
        result = header
        result += f'print_request "GET" "{url}"\n'
        result += match.group(2)
        return result
    
    content = re.sub(pattern2, replace_without_body, content, flags=re.MULTILINE)
    
    # 为所有 PASSED 消息添加 HTTP 状态码
    content = re.sub(
        r'echo -e "\$\{GREEN\}✓ (TC-[A-Z]+-\d+) PASSED\$\{NC\}"',
        r'echo -e "${GREEN}✓ \1 PASSED (HTTP: $HTTP_CODE)${NC}"',
        content
    )
    
    # 为成功的测试添加响应输出标签
    content = re.sub(
        r'(echo -e "\$\{GREEN\}✓ TC-[A-Z]+-\d+ PASSED \(HTTP: \$HTTP_CODE\)\$\{NC\}"\n\s+PASSED=\$\(\(PASSED\+1\)\)\n)(\s+echo "\$RESPONSE_BODY" \| jq)',
        r'\1    echo -e "${GREEN}[响应]${NC}"\n\2',
        content,
        flags=re.MULTILINE
    )
    
    return content

if __name__ == "__main__":
    input_file = sys.argv[1] if len(sys.argv) > 1 else "test-all-apis.sh"
    
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 检查是否已经有 print_request 函数
    if 'print_request()' not in content:
        print("错误: 脚本中没有找到 print_request 函数定义")
        sys.exit(1)
    
    modified_content = add_request_logging(content)
    
    # 输出到标准输出
    print(modified_content)
