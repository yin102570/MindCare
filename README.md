<div align="center">

<img src="https://img.shields.io/badge/Python-3.8+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
<img src="https://img.shields.io/badge/Flask-2.3.3-000000?style=for-the-badge&logo=flask&logoColor=white" alt="Flask">
<img src="https://img.shields.io/badge/MySQL-8.0+-4479A1?style=for-the-badge&logo=mysql&logoColor=white" alt="MySQL">
<img src="https://img.shields.io/badge/原生_JavaScript-ES6-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black" alt="JS">
<img src="https://img.shields.io/badge/Chart.js-4.4.0-FF6384?style=for-the-badge&logo=chartdotjs&logoColor=white" alt="Chart.js">
<img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT">

</div>

<br>

# 🧠 MindCare — 心理健康评估与干预管理系统

> **数据库系统课程项目** | 基于 B/S 架构，MySQL 触发器 + 存储过程 + 视图全覆盖

<br>

## ✨ 亮点速览

<table>
<tr>
<td width="50%">

### 🔧 数据库核心技术
- **3 项核心对象**：1 个触发器 + 2 个存储过程 + 8 个视图
- **8 张业务表**，10 条外键约束，级联删除策略
- **20+ 索引优化**方案（含联合索引、覆盖索引）
- **3 级权限角色**管理设计

</td>
<td width="50%">

### 🎯 交互式教学演示
- **4 大演示模块**：事务回滚、触发器约束、存储过程校验、视图查询
- **自定义参数输入**：可输入任意值验证数据库约束机制
- **实时 Navicat 联动**：操作后 `Ctrl+R` 即可看到数据变化

</td>
</tr>
</table>

<br>

## 📸 界面展示

| 管理员仪表盘 | 测评作答界面 | 数据库操作演示 |
|:---:|:---:|:---:|
| 数据总览 + 趋势图 + 风险分布 | 逐题作答 + 实时计分 | 事务/触发器/存储过程/视图 |

> 💡 打开 `index.html` 或启动 Flask 后访问 `http://localhost:5000` 即可浏览所有页面。

<br>

## 🏗 系统架构

```
┌──────────────────────────────────────────────────────┐
│                    前端 (SPA)                         │
│   index.html  │  Chart.js  │  Vanilla JS (ES6)       │
├──────────────────────────────────────────────────────┤
│                  RESTful API                          │
│         Flask 2.3.3  │  Flask-CORS  │  Session       │
├──────────────────────────────────────────────────────┤
│                    MySQL 8.0                          │
│  ┌──────────┐ ┌───────────┐ ┌──────┐ ┌──────────┐  │
│  │ 触发器   │ │ 存储过程   │ │ 视图 │ │ 事务管理 │  │
│  │ Trigger  │ │Procedure  │ │ View │ │Transaction│  │
│  └──────────┘ └───────────┘ └──────┘ └──────────┘  │
├──────────────────────────────────────────────────────┤
│  8 张表  │  10 条外键  │  4 级风险等级  │  级联删除  │
└──────────────────────────────────────────────────────┘
```

<br>

## 📊 数据库设计（ER 关系）

```
                    ┌──────────────┐
                    │  counselors  │  咨询师
                    │  name, sp... │
                    └──────┬───────┘
                           │ 1:N
                           ▼
┌──────────┐     ┌──────────────────┐     ┌──────────────┐
│  scales  │────▶│   assessments    │◀────│    users     │
│  量表    │     │  评估记录        │     │   学生用户   │
│ name, max│     │ total_score,level│     │student_id,dep│
└────┬─────┘     └──┬──────┬────┬───┘     └──────┬───────┘
     │              │      │    │                │
     │ 1:N          │ 1:N  │    │ 1:1            │ 1:N
     ▼              ▼      │    ▼                ▼
┌──────────┐  ┌──────────┐ │  ┌────────────┐  ┌──────────┐
│ questions│  │ answers  │ │  │risk_levels │  │interven- │
│  题目    │  │  答题    │ │  │  风险等级  │  │  tions   │
│opt_0~opt3│  │selected  │ │  │risk_score  │  │干预任务  │
│          │  │_score(0-3│ │  │safe/watch/ │  │priority  │
│          │  │          │ │  │warn/crisis │  │pending.. │
└──────────┘  └──────────┘ │  └────────────┘  └──────────┘
                           │
                    ┌──────┴────────┐
                    │trg_auto_inter │
                    │ AFTER INSERT  │
                    │ 自动生成干预  │
                    └───────────────┘
```

<br>

## 🔗 数据库对象详解

### 触发器 — `trg_auto_intervention`

提交评估后 **MySQL 自动执行**，无需应用层代码：

| 评估等级 | 风险等级 | 干预优先级 | 是否生成干预 |
|:---:|:---:|:---:|:---:|
| `severe` | 🚨 `crisis` | `urgent` | ✅ |
| `moderate` | ⚠️ `warning` | `high` | ✅ |
| `mild` | 🟡 `watch` | — | ❌ |
| `normal` | 🟢 `safe` | — | ❌ |

### 存储过程

| 过程 | 功能 | 算法 |
|------|------|------|
| `sp_calc_risk_score` | 加权风险计算 | 最近3次 × 时间权重(3:2:1) × 0.6 + 历史最高 × 0.4 |
| `sp_update_intervention` | 干预状态更新 | 参数校验 + `completed` 时自动降级风险 |

### 视图（8 个）

| 视图 | JOIN 表数 | 用途 |
|------|:---:|------|
| `v_dept_mental_stats` | 2 | 院系心理健康综合统计 |
| `v_intervention_detail` | 4 | 干预任务详情（学生+咨询师） |
| `v_high_risk_users` | 5 | 高风险用户 ⚡ 最多 5 表联查 |
| `v_counselor_workload` | 2 | 咨询师工作量排行 |
| `v_monthly_trend` | 2 | 月度趋势分析 |
| `v_daily_assess_report` | 2 | 每日评估报表 |
| `v_scale_usage_stats` | 2 | 量表使用频次 |
| `v_user_assess_history` | 4 | 用户评估完整轨迹 |

<br>

## 🚀 快速启动

### 前置要求

- **Python** ≥ 3.8
- **MySQL** ≥ 8.0
- **Node.js**（仅报告生成 `gen_report.js` 需要）

### 1️⃣ 初始化数据库

```sql
CREATE DATABASE IF NOT EXISTS mindcare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mindcare;
SOURCE database/mindcare_init.sql;
SOURCE database/mindcare_demo_data.sql;
```

### 2️⃣ 安装依赖

```bash
pip install -r backend/requirements.txt
```

| 依赖 | 版本 | 用途 |
|------|------|------|
| Flask | 2.3.3 | Web 框架 |
| Flask-CORS | 4.0.0 | 跨域支持 |
| PyMySQL | 1.1.0 | MySQL 连接驱动 |
| Werkzeug | 2.3.7 | SHA256 密码哈希 |

### 3️⃣ 配置数据库连接

编辑 `app.py` 中 `DB_CONFIG`：

```python
DB_CONFIG = {
    'host':     'localhost',
    'port':     3306,
    'user':     'root',
    'password': 'your_password',
    'database': 'mindcare',
    'charset':  'utf8mb4',
}
```

### 4️⃣ 启动

```bash
python app.py
```

浏览器打开 **http://localhost:5000**

<br>

## 👥 演示账号

| 角色 | 用户名 | 密码 | 说明 |
|:---:|------|------|------|
| 管理员 | `admin` | `admin123` | 心理咨询中心，可访问管理后台 |
| 学生 | `2021001001` | `123456` | 计算机学院学生 |

<br>

## 🎮 数据库操作演示（核心特色）

> 管理员登录 → 左侧导航 **数据库系统 → 数据库操作**

### 🗑 事务删除

| 操作 | 说明 |
|------|------|
| **正常级联删除** | 输入用户ID → 5 张表（interventions → risk_levels → assessments → answers → users）原子性级联删除 |
| **回滚测试** | 删除不存在的用户 → 事务检测失败 → **全部回滚** |
| **🔧 自定义ID** | 输入任意 user_id 测试不同场景 |
| **💾 恢复数据** | 一键恢复被删除的演示用户（事务批量插入） |

### ⚡ 触发器约束

| 测试场景 | 默认值 | 🔧 可自定义 |
|----------|:---:|:---:|
| 非法 level 值 | `"critical"` | ✅ 任意字符串 |
| 不存在 user_id | `9999` | ✅ 任意 ID |
| 负数分数 | `-5` | ✅ 任意数值 |
| 越界答案分值 | `5` | ✅ 任意分值 |

> 🎯 **亮点**：每条测试都有自定义输入框，输入**合法值**（如 `level="normal"`、`user_id=1`）会**成功写入**，后端回查数据库返回实际插入数据，Navicat 按 `Ctrl+R` 可实时验证。

### 📦 存储过程

| 测试场景 | 默认值 | 🔧 可自定义 |
|----------|:---:|:---:|
| 不存在用户调用 | `user_id=9999` | ✅ 任意 ID |
| 非法状态值 | `"deleted"` | ✅ 任意状态 |
| 不存在干预任务 | `id=99999` | ✅ 任意干预 ID |

> 🎯 **亮点**：输入合法参数 → 存储过程**确实执行**，后端回查 risk_levels / interventions 的实际变化并返回。

### 👁 视图查询

点击任意视图按钮 → 查看封装后的多表 JOIN 结果，支持分页和结果截断。

<br>

## 📡 API 端点

<details>
<summary><b>🔐 认证接口（3 个）</b></summary>

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/login` | 登录（学号/邮箱），返回 token |
| POST | `/api/logout` | 登出 |
| GET | `/api/me` | 当前用户 + 风险等级 |

</details>

<details>
<summary><b>👨‍🎓 学生端（6 个）</b></summary>

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/my/profile` | 心理档案 |
| GET | `/api/my/assessments` | 评估历史 |
| GET | `/api/scales` | 量表列表 |
| GET | `/api/scales/<id>/questions` | 量表题目 |
| POST | `/api/assessments` | 提交评估（触发存储过程） |
| GET | `/api/assessments/history` | 历史记录 |

</details>

<details>
<summary><b>👨‍💼 管理员端（7 个）</b></summary>

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/admin/dashboard` | 仪表盘（趋势图+分布） |
| GET | `/api/admin/users` | 用户列表 |
| DELETE | `/api/admin/users/<uid>` | **事务级联删除** |
| GET | `/api/admin/dept-stats` | 院系统计 |
| GET | `/api/admin/interventions` | 干预任务（视图查询） |
| PUT | `/api/admin/interventions/<iid>` | 更新干预（存储过程） |
| POST | `/api/admin/calc-risk` | 风险计算（存储过程） |

</details>

<details>
<summary><b>🧪 演示接口（7 个）</b></summary>

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/demo/trigger-test` | 触发器正常演示 |
| POST | `/api/demo/trigger-violation` | 触发器约束违背 |
| POST | `/api/demo/procedure-test` | 存储过程正常演示 |
| POST | `/api/demo/procedure-violation` | 存储过程参数校验 |
| GET | `/api/demo/view-query` | 视图查询（8 个白名单） |
| GET | `/api/demo/delete-verify` | 删除前数据验证 |
| POST | `/api/demo/restore-users` | 恢复演示用户 |

</details>

<br>

## 📁 项目结构

```
MindCare/
├── app.py                        # Flask 后端（42 KB）, 23 个 API
├── index.html                    # SPA 前端（110 KB）, 管理员/学生端
├── gen_report.js                 # Word 报告自动生成（Node.js）
├── .gitignore
├── README.md
├── 工程作业报告.docx / .pdf       # 完整作业报告
├── backend/
│   └── requirements.txt          # Python 依赖
├── database/
│   ├── mindcare_init.sql         # 核心 DDL（8 表 + 触发器 + 存储过程 + 视图）
│   └── mindcare_demo_data.sql    # 演示数据（8 用户 + 量表 + 题目）
└── MindCare_数据库优化方案.sql    # 优化方案（20+ 索引 + 新存储过程 + 新触发器）
```

<br>

## 🛡 安全特性

- **密码哈希**：MySQL `SHA2(.., 256)` 存储，不存储明文
- **Token 认证**：`secrets.token_hex(32)` 生成随机令牌
- **SQL 注入防护**：全部使用参数化查询 `%s` 占位符
- **权限校验**：每个 API 校验 token + 角色，管理员接口校验 `department='心理咨询中心'`
- **视图白名单**：演示接口仅允许预定义的 8 个视图查询

<br>

## 📈 优化方案

`MindCare_数据库优化方案.sql` 包含遵循 **"只增不减"原则** 的完整优化：

| 类别 | 内容 |
|------|------|
| 📊 索引优化 | 20+ 条（联合索引、唯一索引、覆盖索引） |
| ✅ CHECK 约束 | 6 个新增约束（分数范围、日期范围、状态枚举） |
| 📝 字段注释 | 全库字段补充完整中文 COMMENT |
| 🔧 存储过程 | 5 个新增（批量操作、分页查询、仪表盘统计） |
| ⚡ 触发器 | 5 个新增（操作日志、数据校验、状态联动） |
| 🗃 拓展表 | 4 张（操作日志、用户分类、预警规则、排班表） |
| 👑 权限管理 | 3 个角色 + 分层 GRANT 权限 |

<br>

## 🚀 部署到 GitHub

```bash
git init
git add .
git commit -m "🎉 Initial commit: MindCare 心理健康管理系统"
git branch -M main
git remote add origin https://github.com/yin102570/MindCare.git
git push -u origin main
```

<br>

## 📄 许可证

本项目为**数据库系统工程课程作业**，采用 MIT License，仅供学习参考。

<br>

<div align="center">

**⭐ 如果这个项目对你有帮助，请给一个 Star！**

Made with ❤️ by [yin102570](https://github.com/yin102570)

</div>
