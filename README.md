# MindCare 心理健康评估与干预管理系统

> 数据库系统工程作业 | MySQL 8.0 + Flask + 原生前端

---

## 目录

- [项目简介](#项目简介)
- [功能模块](#功能模块)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速启动](#快速启动)
- [数据库设计](#数据库设计)
- [API 接口文档](#api-接口文档)
- [演示账号](#演示账号)
- [数据库操作演示](#数据库操作演示)

---

## 项目简介

MindCare 是一个基于 B/S 架构的心理健康评估与干预管理平台。学生可在线完成心理量表测评，系统自动计算风险等级并生成干预任务；管理员可管理用户、干预任务、查看院系统计数据。

**核心特性：**
- 触发器自动生成干预任务，全程无需应用层干预
- 事务保证用户注销时 5 表级联删除的原子性
- 存储过程实现加权风险计算（时间衰减 3:2:1）
- 8 个视图封装复杂多表 JOIN，统一数据出口

---

## 功能模块

### 学生端

| 模块 | 说明 |
|------|------|
| 仪表盘 | 数据总览、趋势图、风险分布 |
| 开始测评 | 选择量表（PHQ-9 / GAD-7 / PSS-10 / PSQI），逐题作答，实时计分 |
| 测评记录 | 查看个人评估历史、风险等级、干预状态 |
| 我的档案 | 基本信息、风险评估、干预记录 |

### 管理员端

| 模块 | 说明 |
|------|------|
| 数据总览 | 注册用户数 / 累计测评 / 待处理干预 / 高风险用户 + 趋势图 |
| 用户管理 | 用户列表 + 事务级联删除 |
| 干预管理 | 按状态筛选，调用存储过程更新状态 |
| 院系统计 | 图表 / 表格 / 详细分析三种视图，支持 CSV 导出 |
| 风险计算 | 选择用户 → 调用存储过程计算综合风险分 |

### 数据库操作演示

| 演示 | 涉及数据库操作 |
|------|----------------|
| 事务删除 | 正常级联删除 + 违背回滚 |
| 触发器 | 提交评估自动生成干预 + 4 种约束违背 |
| 存储过程 | 加权风险计算 + 3 种参数校验 |
| 视图查询 | 8 个视图白名单查询 |

---

## 技术栈

| 层级 | 技术 |
|------|------|
| 后端框架 | Python 3 + Flask 2.3.3 |
| 数据库 | MySQL 8.0 + PyMySQL 1.1.0 |
| 前端 | 原生 HTML / CSS / JavaScript + Chart.js 4.4.0 |
| 认证 | Token 认证（SHA256 密码哈希 + secrets 随机令牌） |
| 跨域 | Flask-CORS 4.0.0 |

---

## 项目结构

```
MindCare/
├── app.py                          # Flask 后端主程序（936 行）
├── index.html                      # 单页面前端应用（1994 行）
├── gen_report.js                   # Word 报告生成脚本
├── SQL_code.sql                    # 补充 SQL 脚本
├── MindCare_数据库优化方案.sql      # 数据库全面优化方案（1641 行）
├── README.md                       # 本文件
├── 工程作业报告.docx               # 作业报告
├── backend/
│   └── requirements.txt            # Python 依赖
└── database/
    ├── mindcare_init.sql           # 核心初始化脚本（8 表 + 触发器 + 存储过程 + 视图）
    └── mindcare_demo_data.sql      # 演示数据
```

---

## 快速启动

### 1. 环境要求

- Python 3.8+
- MySQL 8.0+
- Node.js（仅报告生成需要）

### 2. 初始化数据库

打开 MySQL 命令行或 Navicat，依次执行：

```bash
# 创建数据库
CREATE DATABASE IF NOT EXISTS mindcare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mindcare;

# 导入核心结构
SOURCE database/mindcare_init.sql;

# 导入演示数据
SOURCE database/mindcare_demo_data.sql;
```

### 3. 安装 Python 依赖

```bash
cd backend
pip install -r requirements.txt
```

依赖清单（`backend/requirements.txt`）：

```
flask==2.3.3
flask-cors==4.0.0
pymysql==1.1.0
Werkzeug==2.3.7
```

### 4. 配置数据库连接

在 `app.py` 中确认连接信息：

```python
DB_CONFIG = {
    'host':      'localhost',
    'port':      3306,
    'user':      'root',
    'password':  '123456',
    'database':  'mindcare',
    'charset':   'utf8mb4',
    'cursorclass': pymysql.cursors.DictCursor
}
```

### 5. 启动应用

```bash
cd MindCare          # 回到项目根目录
python app.py        # 启动后端服务
```

浏览器访问：**http://localhost:5000**

---

## 数据库设计

### 核心表（8 张）

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| `counselors` | 心理咨询师 | counselor_id, name, specialty, available |
| `users` | 学生用户 | user_id, student_id, department, password_hash |
| `scales` | 心理量表 | scale_id, name, type, max_score |
| `questions` | 量表题目 | question_id, scale_id(FK), seq_no, opt_0~opt_3 |
| `assessments` | 评估记录 | assess_id, user_id(FK), scale_id(FK), total_score, level |
| `answers` | 答题明细 | answer_id, assess_id(FK), question_id(FK), selected_score |
| `risk_levels` | 综合风险等级 | risk_id, user_id(UNIQUE FK), risk_score, risk_level |
| `interventions` | 干预任务 | intervention_id, user_id(FK), counselor_id(FK), priority, status |

### 外键关系图

```
counselors ──┐
             │ (counselor_id)
             ├──→ interventions
             │
users ───────┤ (user_id)
             │       │
             │       ├──→ assessments ──→ answers ←── questions ←── scales
             │       │
             │       ├──→ risk_levels
             │       │
             │       └──→ interventions
             │
scales ──────┤ (scale_id)
             └──→ assessments
```

### 触发器

| 名称 | 时机 | 功能 |
|------|------|------|
| `trg_auto_intervention` | AFTER INSERT ON assessments | 根据评估等级自动生成干预任务、分配咨询师、更新风险等级 |

**触发逻辑：**

| 评估等级 | 干预优先级 | 风险等级 |
|----------|-----------|----------|
| severe | urgent | crisis |
| moderate | high | warning |
| mild | — | watch |
| normal | — | safe |

### 存储过程

| 名称 | 参数 | 功能 |
|------|------|------|
| `sp_calc_risk_score` | IN p_user_id, OUT p_risk_level | 加权风险计算：取最近 3 次评估，时间权重 3:2:1，综合分 = 加权平均 × 0.6 + 最高分 × 0.4 |
| `sp_update_intervention` | IN p_intervention_id, IN p_new_status, IN p_notes, OUT p_result | 更新干预任务状态，completed 时自动降级风险等级 |

### 视图（8 个）

| 视图 | 说明 | 涉及表数 |
|------|------|----------|
| `v_dept_mental_stats` | 院系心理健康综合统计 | 2 |
| `v_intervention_detail` | 干预任务详情 | 4 |
| `v_user_assess_history` | 用户评估历史 | 4 |
| `v_daily_assess_report` | 每日评估汇总 | 2 |
| `v_scale_usage_stats` | 量表使用频次统计 | 2 |
| `v_counselor_workload` | 咨询师工作量统计 | 2 |
| `v_high_risk_users` | 高风险用户明细 | 5 |
| `v_monthly_trend` | 月度趋势统计 | 2 |

---

## API 接口文档

### 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/login` | 登录（支持学号/邮箱），返回 token |
| POST | `/api/logout` | 登出 |
| GET | `/api/me` | 获取当前用户信息 + 风险等级 |

### 学生

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/my/profile` | 我的档案 |
| GET | `/api/my/assessments` | 我的评估历史 |
| GET | `/api/scales` | 获取量表列表 |
| GET | `/api/scales/<id>/questions` | 获取量表题目 |
| POST | `/api/assessments` | 提交评估（触发存储过程） |

### 管理员

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/admin/dashboard` | 仪表盘数据 |
| GET | `/api/admin/users` | 用户列表 |
| DELETE | `/api/admin/users/<uid>` | 事务级联删除用户 |
| GET | `/api/admin/dept-stats` | 院系统计 |
| GET | `/api/admin/interventions` | 干预任务列表 |
| PUT | `/api/admin/interventions/<iid>` | 更新干预任务 |
| POST | `/api/admin/calc-risk` | 计算风险分 |

### 演示

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/demo/trigger-test` | 触发器正常演示 |
| POST | `/api/demo/trigger-violation` | 触发器违背演示 |
| POST | `/api/demo/procedure-test` | 存储过程正常演示 |
| POST | `/api/demo/procedure-violation` | 存储过程违背演示 |
| GET | `/api/demo/view-query` | 视图查询 |
| GET | `/api/demo/delete-verify` | 删除前验证 |

---

## 演示账号

| 角色 | 用户名 | 密码 | 说明 |
|------|--------|------|------|
| 管理员 | `admin` | `admin123` | 心理咨询中心，可访问管理后台 |
| 学生 | `2021001001` | `123456` | 计算机学院学生 |

---

## 数据库操作演示

在左侧导航栏 **数据库系统 → 数据库操作** 中，可进行以下演示：

### 1. 事务删除
- **正常删除**：输入用户 ID，5 张表（users → assessments → answers / risk_levels → interventions）原子性级联删除
- **违背回滚**：演示事务中某步失败后全部回滚

### 2. 触发器添加
- **正常触发**：提交评估 → 触发器自动生成干预任务 + 更新风险等级
- **违背演示**（4 种）：
  - 非法 level 值（不在 ENUM 范围）
  - 不存在的外键引用
  - 负数分数（违反 CHECK 约束）
  - NULL 必填字段

### 3. 存储过程更新
- **正常调用**：选择用户 → 调用 `sp_calc_risk_score` 计算加权风险
- **违背演示**（3 种）：
  - 不存在的用户 ID
  - 干预任务不存在
  - 非法状态值

### 4. 视图查询
- 选择任意视图 → 查看封装后的多表 JOIN 结果
- 8 个视图均支持直接查询

---

## 实时查看数据

推荐使用 **Navicat** 连接 MySQL 实时观察数据变化：

1. 新建 MySQL 连接
2. 主机：`localhost` | 端口：`3306` | 用户名：`root` | 密码：`123456`
3. 双击 `mindcare` 库 → 展开 **表** → 双击任意表查看数据
4. 前端操作后按 `Ctrl+R` 刷新即可看到实时变化

---

## 优化方案

项目包含一份完整的数据库优化方案（`MindCare_数据库优化方案.sql`），遵循 **只增不减** 原则：

- 新增 20+ 索引（联合索引、唯一索引）
- 新增 6 个 CHECK 约束
- 全库字段补充完整中文注释
- 存储过程增强（事务控制、异常捕获）
- 新增 5 个存储过程（批量操作、分页查询、仪表盘统计）
- 新增 5 个触发器（数据校验、操作日志）
- 新增 4 张拓展表（日志、分类、预警、排班）
- 3 个权限角色 + 分层权限管理

---

## 许可证

本项目为数据库系统工程作业，仅供学习参考。

---

> 最后更新：2026-05-30
