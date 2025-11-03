# 图片理解应用 (Image Understanding Application)

基于 OpenGVLab/InternVL3-2B-AWQ 模型的图片理解网页应用，支持流式文本输出。

## 功能特点

- 🖼️ **图片上传**: 支持上传图片文件进行分析
- 💬 **文本输入**: 输入问题描述图片内容
- 🤖 **AI 分析**: 使用 InternVL3-2B-AWQ 模型进行图片理解
- 📝 **流式输出**: 实时流式显示分析结果
- 🐳 **Docker 部署**: 一键 Docker 部署
- ☁️ **云端部署**: 支持 EC2 一键部署

## 架构

应用包含以下 4 个服务：

1. **前端 (Frontend)**: Nginx 服务静态 HTML/JavaScript 界面
2. **后端 (Backend)**: FastAPI 处理请求和流式响应
3. **模型服务 (Model)**: InternVL3-2B-AWQ 模型推理服务
4. **反向代理 (Nginx)**: 统一入口，路由分发到前端和后端

## 本地部署

### 环境要求

- Docker
- NVIDIA GPU (推荐，用于模型推理加速) - `first.sh` 会自动检测并配置
- 至少 16GB RAM
- 至少 50GB 存储空间

### 快速开始

1. **进入项目目录**
   ```bash
   cd image_app
   ```

2. **一键部署**
   ```bash
   ./all.sh
   ```

3. **访问应用**
   - 前端界面: http://localhost
   - API 接口: http://localhost/api/

### 手动部署

```bash
# 设置服务器环境 (安装Docker、NVIDIA GPU支持、预下载镜像)
./first.sh

# 构建Docker镜像
./docker_build.sh

# 启动所有容器
./docker_run.sh

# 检查服务状态
docker ps
```

**注意**: `first.sh` 会自动检测 GPU 并下载必要的 NVIDIA 镜像，无需手动干预。

## EC2 云端部署

### 准备工作

1. **启动 EC2 实例**
   - 推荐实例类型: g4dn.xlarge 或更高 (带 GPU)
   - 存储空间: 至少 100GB
   - 安全组: 开放 22(SSH)、80(HTTP)、443(HTTPS) 端口

2. **连接到 EC2**
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

3. **上传代码**
   ```bash
   # 在本地打包
   tar -czf image_app.tar.gz image_app/

   # 上传到 EC2
   scp -i ~/.ssh/tokyo_private.pem image_app.tar.gz ubuntu@ec2-35-75-7-142.ap-northeast-1.compute.amazonaws.com:~/

   ssh -i ~/.ssh/tokyo_private.pem ubuntu@ec2-35-75-7-142.ap-northeast-1.compute.amazonaws.com

   # 在 EC2 上解压
   rm -rf image_app
   tar -xzf image_app.tar.gz
   cd image_app
   ```

4. **一键部署**
   ```bash
   chmod +x *.sh
   ./all.sh
   ```
   **注意**: `all.sh` 会自动调用 `first.sh`，后者会检测 GPU 并下载必要的 NVIDIA 镜像。

### 部署完成后的检查

```bash
# 查看服务状态
sudo docker ps

# 查看容器日志
sudo docker logs image-backend
sudo docker logs image-model

# 检查应用是否可访问
curl http://localhost
```

## API 接口

### POST /api/understand-image

上传图片并获取 AI 分析结果。

**请求参数:**
- `text` (form): 问题描述
- `file` (file): 图片文件

**响应:** Server-Sent Events 流式响应

**示例:**
```javascript
const formData = new FormData();
formData.append('text', '描述这张图片的内容');
formData.append('file', imageFile);

fetch('/api/understand-image', {
    method: 'POST',
    body: formData
}).then(response => {
    const reader = response.body.getReader();
    // 处理流式响应
});
```

## 故障排除

### 常见问题

1. **模型下载失败**
   ```bash
   # 手动下载模型
   sudo docker run --rm -it image-model:latest python3 model_prepare.py
   ```

2. **GPU 不可用**
   ```bash
   # 检查 GPU 状态
   nvidia-smi

   # 检查 NVIDIA Docker
   sudo docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
   ```

3. **端口冲突**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :80
   sudo netstat -tlnp | grep :8000
   sudo netstat -tlnp | grep :23333
   ```

4. **内存不足**
   ```bash
   # 检查系统资源
   free -h
   df -h

   # 增加交换空间
   sudo fallocate -l 8G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

5. **PyTorch/Transformers 依赖问题**
   ```bash
   # 如果遇到 "AutoModel requires the PyTorch library" 或版本检测错误
   # Dockerfile 使用简单的 NVIDIA CUDA 基础镜像，手动安装稳定版本的 PyTorch
   
   # 检查容器内的 PyTorch 版本
   sudo docker exec image-model python3 -c "import torch; print(torch.__version__)"
   
   # 如果出现问题，重新构建模型镜像
   sudo docker build -t image-model:1.0 ./model
   
   # 查看模型服务日志确认依赖是否正确安装
   sudo docker logs image-model | grep -i "pytorch\|transformers"
   
   # 验证 PyTorch 和 CUDA 是否正常工作
   sudo docker exec image-model python3 -c "import torch; print('PyTorch:', torch.__version__); print('CUDA available:', torch.cuda.is_available())"
   ```

### 日志查看

```bash
# 查看容器状态
sudo docker ps

# 查看特定容器日志
sudo docker logs image-backend
sudo docker logs image-model
sudo docker logs image-frontend
sudo docker logs nginx

# 查看系统日志
sudo journalctl -u docker.service
```

## 性能优化

1. **GPU 加速**: 确保 NVIDIA Docker 正确安装
2. **模型缓存**: 模型下载完成后会自动缓存
3. **并发限制**: 根据硬件情况调整并发请求数
4. **内存管理**: 监控内存使用，避免内存泄漏

## 安全注意事项

1. **防火墙**: 只开放必要端口 (22, 80, 443)
2. **HTTPS**: 生产环境建议启用 HTTPS
3. **访问控制**: 考虑添加身份验证机制
4. **资源限制**: 设置容器资源限制防止滥用

## 自定义配置

### 修改模型参数

编辑 `model/Dockerfile` 中的 CMD 参数：
```dockerfile
CMD ["venv/bin/lmdeploy", "serve", "api_server", "/path/to/model", \
     "--backend", "turbomind", \
     "--server-port", "23333", \
     "--model-format", "awq", \
     "--cache-max-entry-count", "0.1", \
     "--model-name", "internvl3-2b-awq"]
```

### 修改前端界面

编辑 `frontend/index.html` 自定义用户界面。

### 添加新功能

1. 在 `backend/app.py` 中添加新的 API 端点
2. 更新 `frontend/index.html` 中的 JavaScript
3. 修改 `nginx/default.conf` 配置路由

## 支持

如果遇到问题，请：

1. 查看容器状态: `sudo docker ps`
2. 查看服务日志: `sudo docker logs [container_name]`
3. 检查系统资源: `sudo docker stats`
4. 验证网络连接: `sudo docker network ls`
5. 查看完整错误信息

## 许可证

本项目仅供学习和研究使用。
