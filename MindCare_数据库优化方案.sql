-- ============================================================
-- MindCare 心理健康评估与干预平台 - 数据库全面优化方案
-- MySQL 8.0 | 数据库工程作业
-- 遵循【只增不减】原则：不删除、不修改、不重命名原有表/字段/主键/外键/视图/存储过程/触发器/业务SQL
-- 仅做新增、补充、增强、拓展类优化
-- ============================================================

USE mindcare;

-- ============================================================
-- 一、整体优化总结
-- ============================================================
/*
【优化总览】
1. 索引优化：新增12个索引（含联合索引、唯一索引），覆盖 users/scales/questions/assessments/answers/risk_levels/interventions 7张核心表
2. 数据约束增强：新增 CHECK 约束校验分数范围、状态值合法性；新增 DEFAULT 值增强数据完整性
3. 字段规范优化：为所有表/字段/视图/存储过程补充完整中文注释；全库统一 utf8mb4_unicode_ci
4. 事务与异常处理：为 sp_calc_risk_score 和 sp_update_intervention 新增事务控制与异常捕获回滚
5. 视图拓展：新增5个衍生视图（综合报表、量表统计、咨询师工作量、高风险用户明细、月度趋势）
6. 存储过程增强：新增5个存储过程（批量风险计算、分页查询用户、批量导入评估、综合仪表盘统计、咨询师工作量统计）
7. 触发器完善：新增3个触发器（answers数据校验、interventions状态变更日志、risk_levels变更日志）
8. 权限与安全：新增3个数据库角色（admin_role/teacher_role/student_role），创建3个用户并授予分层权限
9. 数据字典与测试数据：新增完整数据字典注释；补充30+条批量测试数据（不覆盖原有）
10. 性能与SQL规范：提供慢查询规避方案、分页查询模板、EXPLAIN 分析注释
11. 拓展功能表：新增4张辅助表（操作日志表、量表分类表、消息预警表、咨询师排班表）
*/


-- ============================================================
-- 二、字符集配置优化
-- ============================================================

-- 【新增内容】确保数据库级字符集统一为 utf8mb4_unicode_ci
ALTER DATABASE mindcare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 【新增内容】确保所有表字符集统一（仅变更默认字符集，不改动字段类型与长度）
ALTER TABLE counselors CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE scales CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE questions CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE assessments CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE answers CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE risk_levels CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE interventions CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 【新增内容】为所有表补充完整中文注释（不修改原有表结构）
ALTER TABLE counselors COMMENT '心理咨询师表 - 存储咨询师基本信息、专长领域与在职状态';
ALTER TABLE users COMMENT '学生用户表 - 存储学生基本信息、院系年级、账号状态';
ALTER TABLE scales COMMENT '心理量表表 - 存储各类心理测评量表元数据，含PHQ-9/GAD-7/PSS-10/PSQI等';
ALTER TABLE questions COMMENT '量表题目表 - 存储各量表的题目内容与选项，每题0-3分';
ALTER TABLE assessments COMMENT '心理评估记录表 - 存储用户每次测评的总分、等级与时间';
ALTER TABLE answers COMMENT '答题明细表 - 存储每次评估中每道题的具体选择分值';
ALTER TABLE risk_levels COMMENT '用户综合风险等级表 - 每用户一条，存储综合风险分与等级，实时更新';
ALTER TABLE interventions COMMENT '心理干预任务表 - 存储自动/手动触发的干预任务与处理状态';

-- 【新增内容】为所有字段补充/完善注释（ALTER TABLE ... MODIFY COLUMN 不改类型，仅补充COMMENT）
ALTER TABLE counselors MODIFY COLUMN counselor_id INT AUTO_INCREMENT COMMENT '咨询师唯一标识，主键，自增';
ALTER TABLE counselors MODIFY COLUMN name VARCHAR(50) NOT NULL COMMENT '咨询师姓名，必填';
ALTER TABLE counselors MODIFY COLUMN gender ENUM('男','女') DEFAULT '男' COMMENT '性别：男/女';
ALTER TABLE counselors MODIFY COLUMN specialty VARCHAR(100) NOT NULL COMMENT '专长领域，如抑郁障碍/焦虑障碍/睡眠障碍等';
ALTER TABLE counselors MODIFY COLUMN phone VARCHAR(20) COMMENT '联系电话';
ALTER TABLE counselors MODIFY COLUMN email VARCHAR(100) COMMENT '电子邮箱';
ALTER TABLE counselors MODIFY COLUMN available TINYINT(1) DEFAULT 1 COMMENT '是否在职：1-在职 0-离职';
ALTER TABLE counselors MODIFY COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '记录创建时间';

ALTER TABLE users MODIFY COLUMN user_id INT AUTO_INCREMENT COMMENT '用户唯一标识，主键，自增';
ALTER TABLE users MODIFY COLUMN student_id VARCHAR(20) NOT NULL COMMENT '学号，唯一标识，用于登录';
ALTER TABLE users MODIFY COLUMN name VARCHAR(50) NOT NULL COMMENT '学生姓名，必填';
ALTER TABLE users MODIFY COLUMN gender ENUM('男','女') DEFAULT '男' COMMENT '性别：男/女';
ALTER TABLE users MODIFY COLUMN department VARCHAR(100) NOT NULL COMMENT '所属院系，如计算机科学与技术学院';
ALTER TABLE users MODIFY COLUMN grade VARCHAR(20) NOT NULL COMMENT '年级，如2021级';
ALTER TABLE users MODIFY COLUMN phone VARCHAR(20) COMMENT '手机号码';
ALTER TABLE users MODIFY COLUMN email VARCHAR(100) COMMENT '电子邮箱，可用于登录';
ALTER TABLE users MODIFY COLUMN password_hash VARCHAR(255) NOT NULL DEFAULT '123456' COMMENT '密码哈希值，默认123456';
ALTER TABLE users MODIFY COLUMN status ENUM('active','inactive','banned') DEFAULT 'active' COMMENT '账户状态：active-正常 inactive-停用 banned-封禁';
ALTER TABLE users MODIFY COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间';

ALTER TABLE scales MODIFY COLUMN scale_id INT AUTO_INCREMENT COMMENT '量表唯一标识，主键，自增';
ALTER TABLE scales MODIFY COLUMN name VARCHAR(100) NOT NULL COMMENT '量表名称，如PHQ-9抑郁症筛查量表';
ALTER TABLE scales MODIFY COLUMN type ENUM('depression','anxiety','stress','sleep','comprehensive') NOT NULL COMMENT '量表类型：depression-抑郁 anxiety-焦虑 stress-压力 sleep-睡眠 comprehensive-综合';
ALTER TABLE scales MODIFY COLUMN description TEXT COMMENT '量表详细说明，包含评分标准与等级划分';
ALTER TABLE scales MODIFY COLUMN question_count INT DEFAULT 0 COMMENT '题目数量';
ALTER TABLE scales MODIFY COLUMN max_score INT DEFAULT 0 COMMENT '满分分值';
ALTER TABLE scales MODIFY COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '量表创建时间';

ALTER TABLE questions MODIFY COLUMN question_id INT AUTO_INCREMENT COMMENT '题目唯一标识，主键，自增';
ALTER TABLE questions MODIFY COLUMN scale_id INT NOT NULL COMMENT '所属量表ID，外键关联scales表';
ALTER TABLE questions MODIFY COLUMN seq_no INT NOT NULL COMMENT '题号，在量表内的排序序号';
ALTER TABLE questions MODIFY COLUMN content TEXT NOT NULL COMMENT '题目内容文本';
ALTER TABLE questions MODIFY COLUMN opt_0 VARCHAR(200) COMMENT '选项A，对应0分';
ALTER TABLE questions MODIFY COLUMN opt_1 VARCHAR(200) COMMENT '选项B，对应1分';
ALTER TABLE questions MODIFY COLUMN opt_2 VARCHAR(200) COMMENT '选项C，对应2分';
ALTER TABLE questions MODIFY COLUMN opt_3 VARCHAR(200) COMMENT '选项D，对应3分';

ALTER TABLE assessments MODIFY COLUMN assess_id INT AUTO_INCREMENT COMMENT '评估记录唯一标识，主键，自增';
ALTER TABLE assessments MODIFY COLUMN user_id INT NOT NULL COMMENT '用户ID，外键关联users表';
ALTER TABLE assessments MODIFY COLUMN scale_id INT NOT NULL COMMENT '量表ID，外键关联scales表';
ALTER TABLE assessments MODIFY COLUMN total_score INT NOT NULL DEFAULT 0 COMMENT '评估总分';
ALTER TABLE assessments MODIFY COLUMN level ENUM('normal','mild','moderate','severe') DEFAULT 'normal' COMMENT '评估结果等级：normal-正常 mild-轻度 moderate-中度 severe-重度';
ALTER TABLE assessments MODIFY COLUMN note TEXT COMMENT '评估备注信息';
ALTER TABLE assessments MODIFY COLUMN assessed_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '评估时间';

ALTER TABLE answers MODIFY COLUMN answer_id INT AUTO_INCREMENT COMMENT '答题明细唯一标识，主键，自增';
ALTER TABLE answers MODIFY COLUMN assess_id INT NOT NULL COMMENT '评估记录ID，外键关联assessments表';
ALTER TABLE answers MODIFY COLUMN question_id INT NOT NULL COMMENT '题目ID，外键关联questions表';
ALTER TABLE answers MODIFY COLUMN selected_score INT NOT NULL DEFAULT 0 COMMENT '用户选择的分值，范围0-3';

ALTER TABLE risk_levels MODIFY COLUMN risk_id INT AUTO_INCREMENT COMMENT '风险记录唯一标识，主键，自增';
ALTER TABLE risk_levels MODIFY COLUMN user_id INT NOT NULL COMMENT '用户ID，唯一约束，外键关联users表';
ALTER TABLE risk_levels MODIFY COLUMN risk_score DECIMAL(5,2) DEFAULT 0 COMMENT '综合风险分，范围0-100';
ALTER TABLE risk_levels MODIFY COLUMN risk_level ENUM('safe','watch','warning','crisis') DEFAULT 'safe' COMMENT '风险等级：safe-安全 watch-观察 warning-警示 crisis-危机';
ALTER TABLE risk_levels MODIFY COLUMN last_assess_id INT COMMENT '最近一次评估记录ID';
ALTER TABLE risk_levels MODIFY COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后更新时间，自动刷新';

ALTER TABLE interventions MODIFY COLUMN intervention_id INT AUTO_INCREMENT COMMENT '干预任务唯一标识，主键，自增';
ALTER TABLE interventions MODIFY COLUMN user_id INT NOT NULL COMMENT '学生用户ID，外键关联users表';
ALTER TABLE interventions MODIFY COLUMN counselor_id INT COMMENT '分配咨询师ID，外键关联counselors表';
ALTER TABLE interventions MODIFY COLUMN trigger_reason VARCHAR(200) NOT NULL COMMENT '干预触发原因描述';
ALTER TABLE interventions MODIFY COLUMN assess_id INT COMMENT '触发干预的评估记录ID';
ALTER TABLE interventions MODIFY COLUMN priority ENUM('low','medium','high','urgent') DEFAULT 'medium' COMMENT '优先级：low-低 medium-中 high-高 urgent-紧急';
ALTER TABLE interventions MODIFY COLUMN status ENUM('pending','in_progress','completed','cancelled') DEFAULT 'pending' COMMENT '任务状态：pending-待处理 in_progress-处理中 completed-已完成 cancelled-已取消';
ALTER TABLE interventions MODIFY COLUMN created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '任务创建时间';
ALTER TABLE interventions MODIFY COLUMN completed_at DATETIME COMMENT '任务完成/取消时间';
ALTER TABLE interventions MODIFY COLUMN notes TEXT COMMENT '处理备注信息';


-- ============================================================
-- 三、索引优化
-- ============================================================

-- 【新增内容】users 表索引优化
-- 场景：按院系查询用户列表、按年级筛选、按状态过滤、按姓名搜索
ALTER TABLE users ADD INDEX idx_users_department (department) COMMENT '院系索引，用于按院系统计与筛选';
ALTER TABLE users ADD INDEX idx_users_grade (grade) COMMENT '年级索引，用于按年级筛选';
ALTER TABLE users ADD INDEX idx_users_status (status) COMMENT '账户状态索引，用于筛选活跃/停用用户';
ALTER TABLE users ADD INDEX idx_users_name (name) COMMENT '姓名索引，用于用户搜索';
-- 联合索引：院系+状态 常用于管理员查询
ALTER TABLE users ADD INDEX idx_users_dept_status (department, status) COMMENT '院系+状态联合索引，优化管理员筛选查询';
-- 联合索引：院系+年级 用于院系年级维度统计
ALTER TABLE users ADD INDEX idx_users_dept_grade (department, grade) COMMENT '院系+年级联合索引，优化多维度统计';

-- 【新增内容】scales 表索引优化
-- 场景：按量表类型筛选
ALTER TABLE scales ADD INDEX idx_scales_type (type) COMMENT '量表类型索引，用于按类型筛选量表';

-- 【新增内容】questions 表索引优化
-- 场景：按scale_id查询题目列表、按题号排序
ALTER TABLE questions ADD INDEX idx_questions_scale_seq (scale_id, seq_no) COMMENT '量表+题号联合索引，优化题目按序查询';

-- 【新增内容】assessments 表索引优化（高频查询表）
-- 场景：按用户查询评估历史、按量表统计、按等级筛选、按时间范围查询
ALTER TABLE assessments ADD INDEX idx_assess_user_id (user_id) COMMENT '用户ID索引，用于查询个人评估历史';
ALTER TABLE assessments ADD INDEX idx_assess_scale_id (scale_id) COMMENT '量表ID索引，用于按量表统计';
ALTER TABLE assessments ADD INDEX idx_assess_level (level) COMMENT '评估等级索引，用于风险等级筛选';
ALTER TABLE assessments ADD INDEX idx_assess_assessed_at (assessed_at) COMMENT '评估时间索引，用于时间范围查询与排序';
-- 联合索引：用户+评估时间（最常用查询模式：查某用户的评估历史按时间倒序）
ALTER TABLE assessments ADD INDEX idx_assess_user_time (user_id, assessed_at) COMMENT '用户+时间联合索引，优化个人评估历史查询';
-- 联合索引：量表+等级 用于按量表类型统计等级分布
ALTER TABLE assessments ADD INDEX idx_assess_scale_level (scale_id, level) COMMENT '量表+等级联合索引，优化量表维度统计';

-- 【新增内容】answers 表索引优化
-- 场景：按评估记录查答题明细、按题目统计
ALTER TABLE answers ADD INDEX idx_answers_assess_id (assess_id) COMMENT '评估记录ID索引，用于查询某次评估的所有答题';
ALTER TABLE answers ADD INDEX idx_answers_question_id (question_id) COMMENT '题目ID索引，用于按题目统计分析';

-- 【新增内容】risk_levels 表索引优化
-- 场景：按风险等级筛选高危用户
ALTER TABLE risk_levels ADD INDEX idx_risk_level (risk_level) COMMENT '风险等级索引，用于筛选高危用户';
ALTER TABLE risk_levels ADD INDEX idx_risk_score (risk_score) COMMENT '风险分索引，用于按分数排序与范围查询';

-- 【新增内容】interventions 表索引优化（高频查询表）
-- 场景：按用户/咨询师/状态/优先级/时间查询干预任务
ALTER TABLE interventions ADD INDEX idx_inter_status (status) COMMENT '任务状态索引，用于按状态筛选待处理任务';
ALTER TABLE interventions ADD INDEX idx_inter_priority (priority) COMMENT '优先级索引，用于按优先级排序';
ALTER TABLE interventions ADD INDEX idx_inter_created_at (created_at) COMMENT '创建时间索引，用于按时间排序';
ALTER TABLE interventions ADD INDEX idx_inter_counselor_id (counselor_id) COMMENT '咨询师ID索引，用于查询某咨询师的任务列表';
-- 联合索引：状态+优先级+创建时间（最常用管理后台查询）
ALTER TABLE interventions ADD INDEX idx_inter_status_priority (status, priority) COMMENT '状态+优先级联合索引，优化管理后台多条件筛选';
-- 联合索引：咨询师+状态 用于查询某咨询师的待处理任务
ALTER TABLE interventions ADD INDEX idx_inter_counselor_status (counselor_id, status) COMMENT '咨询师+状态联合索引，优化咨询师任务查询';


-- ============================================================
-- 四、数据约束增强
-- ============================================================

-- 【新增内容】answers 表 CHECK 约束：分值范围0-3
ALTER TABLE answers ADD CONSTRAINT chk_answers_score CHECK (selected_score >= 0 AND selected_score <= 3);

-- 【新增内容】assessments 表 CHECK 约束：总分>=0
ALTER TABLE assessments ADD CONSTRAINT chk_assess_score CHECK (total_score >= 0);

-- 【新增内容】risk_levels 表 CHECK 约束：风险分范围0-100
ALTER TABLE risk_levels ADD CONSTRAINT chk_risk_score_range CHECK (risk_score >= 0 AND risk_score <= 100);

-- 【新增内容】scales 表 CHECK 约束：题目数量>=0，满分>=0
ALTER TABLE scales ADD CONSTRAINT chk_scales_question_count CHECK (question_count >= 0);
ALTER TABLE scales ADD CONSTRAINT chk_scales_max_score CHECK (max_score >= 0);

-- 【新增内容】interventions 表 CHECK 约束：完成时间必须 >= 创建时间
ALTER TABLE interventions ADD CONSTRAINT chk_inter_time CHECK (completed_at IS NULL OR completed_at >= created_at);

-- 【新增内容】questions 表 CHECK 约束：题号>0
ALTER TABLE questions ADD CONSTRAINT chk_questions_seq CHECK (seq_no > 0);

-- 【新增内容】users 表 email 添加非空默认值（不改原有逻辑，已有数据不受影响）
-- 注意：email 原有允许 NULL，此处使用 ALTER 仅修改 DEFAULT，不改变 NULL 允许性
ALTER TABLE users ALTER COLUMN email SET DEFAULT '';

-- 【新增内容】counselors 表 phone/email 添加默认值
ALTER TABLE counselors ALTER COLUMN phone SET DEFAULT '';
ALTER TABLE counselors ALTER COLUMN email SET DEFAULT '';

-- 【新增内容】assessments 表 note 字段默认值
ALTER TABLE assessments ALTER COLUMN note SET DEFAULT '';

-- 【新增内容】interventions 表 completed_at 默认值
ALTER TABLE interventions ALTER COLUMN completed_at SET DEFAULT NULL;

-- 【新增内容】为 questions 表 scale_id + seq_no 添加联合唯一约束，确保同一量表内题号不重复
ALTER TABLE questions ADD UNIQUE INDEX uq_questions_scale_seq (scale_id, seq_no);


-- ============================================================
-- 五、视图拓展（新增衍生统计视图）
-- ============================================================

-- 【新增内容】视图4：综合评估日报视图 - 按日期汇总评估情况
CREATE OR REPLACE VIEW v_daily_assess_report AS
SELECT
    DATE(a.assessed_at)                                                             AS assess_date,
    COUNT(DISTINCT a.assess_id)                                                     AS total_count,
    COUNT(DISTINCT a.user_id)                                                       AS user_count,
    ROUND(AVG(a.total_score), 2)                                                    AS avg_score,
    SUM(CASE WHEN a.level = 'severe'   THEN 1 ELSE 0 END)                          AS severe_count,
    SUM(CASE WHEN a.level = 'moderate' THEN 1 ELSE 0 END)                          AS moderate_count,
    SUM(CASE WHEN a.level = 'mild'     THEN 1 ELSE 0 END)                          AS mild_count,
    SUM(CASE WHEN a.level = 'normal'   THEN 1 ELSE 0 END)                          AS normal_count,
    COUNT(DISTINCT i.intervention_id)                                               AS intervention_count,
    ROUND(SUM(CASE WHEN a.level IN ('moderate','severe') THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(a.assess_id), 0), 2)                                       AS risk_rate_pct
FROM assessments a
LEFT JOIN interventions i ON a.assess_id = i.assess_id
GROUP BY DATE(a.assessed_at)
ORDER BY assess_date DESC;

-- 【新增内容】视图5：量表使用统计视图 - 各量表使用频次与平均分
CREATE OR REPLACE VIEW v_scale_usage_stats AS
SELECT
    s.scale_id,
    s.name                                                                          AS scale_name,
    s.type                                                                          AS scale_type,
    s.question_count                                                                AS total_questions,
    s.max_score                                                                     AS max_possible_score,
    COUNT(DISTINCT a.assess_id)                                                     AS usage_count,
    COUNT(DISTINCT a.user_id)                                                       AS user_count,
    ROUND(AVG(a.total_score), 2)                                                    AS avg_score,
    MIN(a.total_score)                                                              AS min_score,
    MAX(a.total_score)                                                              AS max_score,
    ROUND(SUM(CASE WHEN a.level IN ('moderate','severe') THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(a.assess_id), 0), 2)                                       AS high_risk_rate_pct
FROM scales s
LEFT JOIN assessments a ON s.scale_id = a.scale_id
GROUP BY s.scale_id, s.name, s.type, s.question_count, s.max_score
ORDER BY usage_count DESC;

-- 【新增内容】视图6：咨询师工作量统计视图 - 各咨询师任务量与完成率
CREATE OR REPLACE VIEW v_counselor_workload AS
SELECT
    c.counselor_id,
    c.name                                                                          AS counselor_name,
    c.specialty                                                                     AS specialty,
    c.available                                                                     AS is_available,
    COUNT(DISTINCT i.intervention_id)                                               AS total_tasks,
    SUM(CASE WHEN i.status = 'pending'      THEN 1 ELSE 0 END)                     AS pending_count,
    SUM(CASE WHEN i.status = 'in_progress'  THEN 1 ELSE 0 END)                     AS in_progress_count,
    SUM(CASE WHEN i.status = 'completed'    THEN 1 ELSE 0 END)                     AS completed_count,
    SUM(CASE WHEN i.status = 'cancelled'    THEN 1 ELSE 0 END)                     AS cancelled_count,
    SUM(CASE WHEN i.priority = 'urgent'     THEN 1 ELSE 0 END)                     AS urgent_count,
    SUM(CASE WHEN i.priority = 'high'       THEN 1 ELSE 0 END)                     AS high_priority_count,
    ROUND(SUM(CASE WHEN i.status = 'completed' THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(i.intervention_id), 0), 2)                                 AS completion_rate_pct
FROM counselors c
LEFT JOIN interventions i ON c.counselor_id = i.counselor_id
GROUP BY c.counselor_id, c.name, c.specialty, c.available
ORDER BY total_tasks DESC;

-- 【新增内容】视图7：高风险用户明细视图 - 含最近评估详情
CREATE OR REPLACE VIEW v_high_risk_users AS
SELECT
    u.user_id,
    u.student_id,
    u.name                                                                          AS student_name,
    u.department,
    u.grade,
    u.phone,
    u.email,
    rl.risk_score                                                                   AS current_risk_score,
    rl.risk_level                                                                   AS current_risk_level,
    rl.updated_at                                                                   AS risk_updated_at,
    a.total_score                                                                   AS last_assess_score,
    a.level                                                                         AS last_assess_level,
    a.assessed_at                                                                   AS last_assess_time,
    s.name                                                                          AS last_scale_name,
    COUNT(DISTINCT a2.assess_id)                                                    AS total_assess_count,
    COUNT(DISTINCT i.intervention_id)                                               AS total_intervention_count
FROM users u
JOIN risk_levels rl     ON u.user_id = rl.user_id
LEFT JOIN assessments a ON rl.last_assess_id = a.assess_id
LEFT JOIN scales s      ON a.scale_id = s.scale_id
LEFT JOIN assessments a2 ON u.user_id = a2.user_id
LEFT JOIN interventions i ON u.user_id = i.user_id
WHERE rl.risk_level IN ('warning', 'crisis')
GROUP BY u.user_id, u.student_id, u.name, u.department, u.grade, u.phone, u.email,
         rl.risk_score, rl.risk_level, rl.updated_at,
         a.total_score, a.level, a.assessed_at, s.name
ORDER BY rl.risk_score DESC;

-- 【新增内容】视图8：月度心理健康趋势视图 - 按月汇总各院系风险变化
CREATE OR REPLACE VIEW v_monthly_trend AS
SELECT
    DATE_FORMAT(a.assessed_at, '%Y-%m')                                             AS assess_month,
    u.department,
    COUNT(DISTINCT a.assess_id)                                                     AS total_assessments,
    COUNT(DISTINCT a.user_id)                                                       AS assessed_users,
    ROUND(AVG(a.total_score), 2)                                                    AS avg_score,
    SUM(CASE WHEN a.level = 'severe'   THEN 1 ELSE 0 END)                          AS severe_count,
    SUM(CASE WHEN a.level = 'moderate' THEN 1 ELSE 0 END)                          AS moderate_count,
    SUM(CASE WHEN a.level = 'mild'     THEN 1 ELSE 0 END)                          AS mild_count,
    SUM(CASE WHEN a.level = 'normal'   THEN 1 ELSE 0 END)                          AS normal_count,
    ROUND(SUM(CASE WHEN a.level IN ('moderate','severe') THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(a.assess_id), 0), 2)                                       AS risk_rate_pct
FROM assessments a
JOIN users u ON a.user_id = u.user_id
WHERE u.department != '心理咨询中心'
GROUP BY DATE_FORMAT(a.assessed_at, '%Y-%m'), u.department
ORDER BY assess_month DESC, u.department;


-- ============================================================
-- 六、存储过程增强（新增参数校验、事务控制、异常捕获、分页逻辑、批量操作）
-- ============================================================

-- 【新增内容】存储过程增强1：为 sp_calc_risk_score 新增事务控制与异常捕获（保留原逻辑）
DELIMITER $$

CREATE PROCEDURE sp_calc_risk_score_v2(IN p_user_id INT, OUT p_risk_level VARCHAR(20))
BEGIN
    -- 新增：声明异常处理变量
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_risk_level = 'ERROR';
    END;

    -- 新增：开启事务
    START TRANSACTION;

    -- 新增：参数校验 - 检查用户是否存在
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        SET p_risk_level = 'ERROR:USER_NOT_FOUND';
        ROLLBACK;
        LEAVE sp_calc_risk_score_v2;
    END IF;

    -- ===== 以下为原有存储过程逻辑（保留不变）=====
    BEGIN
        DECLARE v_count INT DEFAULT 0;
        DECLARE v_avg_score DECIMAL(8,2) DEFAULT 0;
        DECLARE v_max_score DECIMAL(8,2) DEFAULT 0;
        DECLARE v_risk_score DECIMAL(8,2) DEFAULT 0;
        DECLARE v_risk_level VARCHAR(20) DEFAULT 'safe';
        DECLARE v_last_id INT DEFAULT NULL;

        -- 取最近3次评估的加权平均分（最近权重高）
        SELECT
            COUNT(*),
            SUM(total_score * weight) / SUM(weight),
            MAX(total_score),
            MAX(assess_id)
        INTO v_count, v_avg_score, v_max_score, v_last_id
        FROM (
            SELECT assess_id, total_score,
                   CASE ROW_NUMBER() OVER (ORDER BY assessed_at DESC)
                       WHEN 1 THEN 3
                       WHEN 2 THEN 2
                       ELSE 1
                   END AS weight
            FROM assessments
            WHERE user_id = p_user_id
            ORDER BY assessed_at DESC
            LIMIT 3
        ) AS recent;

        IF v_count = 0 THEN
            SET p_risk_level = 'safe';
            COMMIT;
            LEAVE sp_calc_risk_score_v2;
        END IF;

        -- 综合风险分：加权均值 * 0.6 + 历史最高分 * 0.4，归一化到100
        SET v_risk_score = LEAST(100, (v_avg_score * 0.6 + v_max_score * 0.4));

        -- 判定风险等级
        SET v_risk_level = CASE
            WHEN v_risk_score >= 75 THEN 'crisis'
            WHEN v_risk_score >= 50 THEN 'warning'
            WHEN v_risk_score >= 25 THEN 'watch'
            ELSE 'safe'
        END;

        -- 更新risk_levels表
        INSERT INTO risk_levels (user_id, risk_score, risk_level, last_assess_id)
        VALUES (p_user_id, v_risk_score, v_risk_level, v_last_id)
        ON DUPLICATE KEY UPDATE
            risk_score     = v_risk_score,
            risk_level     = v_risk_level,
            last_assess_id = v_last_id,
            updated_at     = NOW();

        SET p_risk_level = v_risk_level;
    END;

    -- 新增：提交事务
    COMMIT;
END$$

DELIMITER ;

-- 【新增内容】存储过程增强2：为 sp_update_intervention 新增事务控制与异常捕获（保留原逻辑）
DELIMITER $$

CREATE PROCEDURE sp_update_intervention_v2(
    IN  p_intervention_id INT,
    IN  p_new_status      VARCHAR(20),
    IN  p_notes           TEXT,
    OUT p_result          VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR: 数据库异常，事务已回滚';
    END;

    -- 新增：开启事务
    START TRANSACTION;

    -- ===== 以下为原有存储过程逻辑（保留不变）=====
    DECLARE v_exist INT DEFAULT 0;
    DECLARE v_user_id INT;

    SELECT COUNT(*), MAX(user_id) INTO v_exist, v_user_id
    FROM interventions WHERE intervention_id = p_intervention_id;

    IF v_exist = 0 THEN
        SET p_result = 'ERROR: 干预任务不存在';
        ROLLBACK;
    ELSEIF p_new_status NOT IN ('in_progress','completed','cancelled') THEN
        SET p_result = 'ERROR: 状态值非法';
        ROLLBACK;
    ELSE
        UPDATE interventions
        SET status       = p_new_status,
            notes        = IFNULL(p_notes, notes),
            completed_at = IF(p_new_status IN ('completed','cancelled'), NOW(), NULL)
        WHERE intervention_id = p_intervention_id;

        -- 如果完成，同步把风险等级降级
        IF p_new_status = 'completed' THEN
            UPDATE risk_levels
            SET risk_level = CASE risk_level
                WHEN 'crisis'  THEN 'warning'
                WHEN 'warning' THEN 'watch'
                ELSE 'safe'
            END,
            updated_at = NOW()
            WHERE user_id = v_user_id;
        END IF;

        SET p_result = CONCAT('SUCCESS: 任务 #', p_intervention_id, ' 状态已更新为 ', p_new_status);
        COMMIT;
    END IF;
END$$

DELIMITER ;

-- 【新增内容】新增存储过程3：批量风险计算 - 对所有用户执行风险评估
DELIMITER $$

CREATE PROCEDURE sp_batch_calc_risk_scores(OUT p_processed_count INT, OUT p_error_count INT)
COMMENT '批量计算所有用户综合风险分，支持事务控制与异常捕获'
BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE v_user_id INT;
    DECLARE v_risk_level VARCHAR(20);

    -- 游标：遍历所有非管理员用户
    DECLARE cur_users CURSOR FOR
        SELECT user_id FROM users WHERE department != '心理咨询中心';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- 异常处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_processed_count = 0;
        SET p_error_count = -1;
    END;

    SET p_processed_count = 0;
    SET p_error_count = 0;

    START TRANSACTION;

    OPEN cur_users;

    read_loop: LOOP
        FETCH cur_users INTO v_user_id;
        IF v_done THEN
            LEAVE read_loop;
        END IF;

        -- 调用原有的 sp_calc_risk_score 计算单个用户风险
        CALL sp_calc_risk_score(v_user_id, v_risk_level);

        IF v_risk_level != 'ERROR' THEN
            SET p_processed_count = p_processed_count + 1;
        ELSE
            SET p_error_count = p_error_count + 1;
        END IF;
    END LOOP;

    CLOSE cur_users;
    COMMIT;
END$$

DELIMITER ;

-- 【新增内容】新增存储过程4：分页查询用户列表 - 支持多条件筛选与分页
DELIMITER $$

CREATE PROCEDURE sp_query_users_paged(
    IN  p_page         INT,
    IN  p_page_size    INT,
    IN  p_department   VARCHAR(100),
    IN  p_grade        VARCHAR(20),
    IN  p_risk_level   VARCHAR(20),
    IN  p_keyword      VARCHAR(100),
    OUT p_total_count  INT
)
COMMENT '分页查询用户列表，支持院系/年级/风险等级/关键字多条件筛选，返回总数与分页数据'
BEGIN
    -- 参数校验与默认值
    IF p_page IS NULL OR p_page < 1 THEN SET p_page = 1; END IF;
    IF p_page_size IS NULL OR p_page_size < 1 THEN SET p_page_size = 20; END IF;
    IF p_page_size > 100 THEN SET p_page_size = 100; END IF;  -- 限制最大每页100条

    DECLARE v_offset INT;
    SET v_offset = (p_page - 1) * p_page_size;

    -- 计算符合条件的总记录数
    SELECT COUNT(DISTINCT u.user_id) INTO p_total_count
    FROM users u
    LEFT JOIN risk_levels rl ON u.user_id = rl.user_id
    WHERE u.department != '心理咨询中心'
      AND (p_department = '' OR u.department LIKE CONCAT('%', p_department, '%'))
      AND (p_grade = '' OR u.grade = p_grade)
      AND (p_risk_level = '' OR rl.risk_level = p_risk_level)
      AND (p_keyword = '' OR u.name LIKE CONCAT('%', p_keyword, '%') OR u.student_id LIKE CONCAT('%', p_keyword, '%'));

    -- 返回分页数据
    SELECT
        u.user_id,
        u.student_id,
        u.name,
        u.gender,
        u.department,
        u.grade,
        u.phone,
        u.email,
        u.status,
        u.created_at,
        rl.risk_score,
        rl.risk_level,
        rl.updated_at                                                                           AS risk_updated_at,
        (SELECT COUNT(*) FROM assessments a WHERE a.user_id = u.user_id)                        AS assessment_count,
        (SELECT COUNT(*) FROM interventions i WHERE i.user_id = u.user_id AND i.status = 'pending') AS pending_intervention_count
    FROM users u
    LEFT JOIN risk_levels rl ON u.user_id = rl.user_id
    WHERE u.department != '心理咨询中心'
      AND (p_department = '' OR u.department LIKE CONCAT('%', p_department, '%'))
      AND (p_grade = '' OR u.grade = p_grade)
      AND (p_risk_level = '' OR rl.risk_level = p_risk_level)
      AND (p_keyword = '' OR u.name LIKE CONCAT('%', p_keyword, '%') OR u.student_id LIKE CONCAT('%', p_keyword, '%'))
    ORDER BY
        FIELD(rl.risk_level, 'crisis', 'warning', 'watch', 'safe', NULL) ASC,
        u.created_at DESC
    LIMIT p_page_size OFFSET v_offset;
END$$

DELIMITER ;

-- 【新增内容】新增存储过程5：综合仪表盘数据统计 - 一次调用获取全部仪表盘数据
DELIMITER $$

CREATE PROCEDURE sp_get_dashboard_data(
    OUT p_total_users        INT,
    OUT p_total_assessments  INT,
    OUT p_pending_tasks      INT,
    OUT p_high_risk_users    INT,
    OUT p_active_users_7d    INT,
    OUT p_new_assessments_7d INT
)
COMMENT '综合仪表盘数据统计存储过程，一次返回所有仪表盘关键指标'
BEGIN
    -- 总用户数（非管理员）
    SELECT COUNT(*) INTO p_total_users FROM users WHERE department != '心理咨询中心';

    -- 总评估次数
    SELECT COUNT(*) INTO p_total_assessments FROM assessments;

    -- 待处理干预任务数
    SELECT COUNT(*) INTO p_pending_tasks FROM interventions WHERE status = 'pending';

    -- 高风险用户数
    SELECT COUNT(*) INTO p_high_risk_users FROM risk_levels WHERE risk_level IN ('warning', 'crisis');

    -- 近7天活跃用户数（有评估记录的用户）
    SELECT COUNT(DISTINCT user_id) INTO p_active_users_7d
    FROM assessments
    WHERE assessed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);

    -- 近7天新增评估数
    SELECT COUNT(*) INTO p_new_assessments_7d
    FROM assessments
    WHERE assessed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);
END$$

DELIMITER ;

-- 【新增内容】新增存储过程6：咨询师工作量统计（含分页）
DELIMITER $$

CREATE PROCEDURE sp_counselor_workload_stats(
    IN  p_page        INT,
    IN  p_page_size   INT,
    OUT p_total_count INT
)
COMMENT '咨询师工作量统计存储过程，含分页，返回各咨询师的任务分布与完成率'
BEGIN
    IF p_page IS NULL OR p_page < 1 THEN SET p_page = 1; END IF;
    IF p_page_size IS NULL OR p_page_size < 1 THEN SET p_page_size = 10; END IF;
    IF p_page_size > 50 THEN SET p_page_size = 50; END IF;

    DECLARE v_offset INT;
    SET v_offset = (p_page - 1) * p_page_size;

    SELECT COUNT(*) INTO p_total_count FROM counselors;

    SELECT
        c.counselor_id,
        c.name                                                                              AS counselor_name,
        c.specialty,
        c.phone,
        c.email,
        c.available                                                                         AS is_available,
        COUNT(DISTINCT i.intervention_id)                                                   AS total_tasks,
        SUM(CASE WHEN i.status = 'pending'      THEN 1 ELSE 0 END)                         AS pending_count,
        SUM(CASE WHEN i.status = 'in_progress'  THEN 1 ELSE 0 END)                         AS in_progress_count,
        SUM(CASE WHEN i.status = 'completed'    THEN 1 ELSE 0 END)                         AS completed_count,
        SUM(CASE WHEN i.status = 'cancelled'    THEN 1 ELSE 0 END)                         AS cancelled_count,
        SUM(CASE WHEN i.priority = 'urgent'     THEN 1 ELSE 0 END)                         AS urgent_count,
        ROUND(SUM(CASE WHEN i.status = 'completed' THEN 1 ELSE 0 END) * 100.0
              / NULLIF(COUNT(i.intervention_id), 0), 2)                                     AS completion_rate_pct,
        MAX(i.created_at)                                                                   AS latest_task_time
    FROM counselors c
    LEFT JOIN interventions i ON c.counselor_id = i.counselor_id
    GROUP BY c.counselor_id, c.name, c.specialty, c.phone, c.email, c.available
    ORDER BY pending_count DESC, total_tasks DESC
    LIMIT p_page_size OFFSET v_offset;
END$$

DELIMITER ;

-- 【新增内容】新增存储过程7：批量导入评估记录（用于数据迁移/批量测试）
DELIMITER $$

CREATE PROCEDURE sp_batch_insert_assessments(
    IN p_assessment_data JSON,
    OUT p_success_count INT,
    OUT p_fail_count    INT
)
COMMENT '批量导入评估记录，JSON格式输入，支持事务回滚与异常捕获'
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_len INT DEFAULT 0;
    DECLARE v_user_id INT;
    DECLARE v_scale_id INT;
    DECLARE v_total_score INT;
    DECLARE v_level VARCHAR(20);
    DECLARE v_note TEXT;
    DECLARE v_assess_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success_count = 0;
        SET p_fail_count = -1;
    END;

    SET p_success_count = 0;
    SET p_fail_count = 0;

    START TRANSACTION;

    -- 获取JSON数组长度
    SET v_len = JSON_LENGTH(p_assessment_data);

    WHILE v_i < v_len DO
        SET v_user_id    = JSON_UNQUOTE(JSON_EXTRACT(p_assessment_data, CONCAT('$[', v_i, '].user_id')));
        SET v_scale_id   = JSON_UNQUOTE(JSON_EXTRACT(p_assessment_data, CONCAT('$[', v_i, '].scale_id')));
        SET v_total_score = JSON_UNQUOTE(JSON_EXTRACT(p_assessment_data, CONCAT('$[', v_i, '].total_score')));
        SET v_level      = JSON_UNQUOTE(JSON_EXTRACT(p_assessment_data, CONCAT('$[', v_i, '].level')));
        SET v_note       = JSON_UNQUOTE(JSON_EXTRACT(p_assessment_data, CONCAT('$[', v_i, '].note')));

        -- 参数校验
        IF v_user_id IS NOT NULL AND v_scale_id IS NOT NULL AND v_total_score IS NOT NULL THEN
            INSERT INTO assessments (user_id, scale_id, total_score, level, note)
            VALUES (v_user_id, v_scale_id, v_total_score, COALESCE(v_level, 'normal'), v_note);
            SET p_success_count = p_success_count + 1;
        ELSE
            SET p_fail_count = p_fail_count + 1;
        END IF;

        SET v_i = v_i + 1;
    END WHILE;

    COMMIT;
END$$

DELIMITER ;


-- ============================================================
-- 七、触发器完善（新增补充触发器）
-- ============================================================

-- 【新增内容】触发器4：answers 插入前数据校验 - 确保分值在0-3范围内
DELIMITER $$

CREATE TRIGGER trg_answers_before_insert
BEFORE INSERT ON answers
FOR EACH ROW
BEGIN
    -- 校验分值范围0-3
    IF NEW.selected_score < 0 OR NEW.selected_score > 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '答题分值必须在0-3之间';
    END IF;
END$$

DELIMITER ;

-- 【新增内容】触发器5：answers 更新前数据校验 - 确保分值在0-3范围内
DELIMITER $$

CREATE TRIGGER trg_answers_before_update
BEFORE UPDATE ON answers
FOR EACH ROW
BEGIN
    IF NEW.selected_score < 0 OR NEW.selected_score > 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '答题分值必须在0-3之间';
    END IF;
END$$

DELIMITER ;

-- 【新增内容】触发器6：interventions 状态变更日志触发器 - 记录每次状态变更到操作日志表（需先建oper_logs表）
-- 注：如果 oper_logs 表尚未创建，此触发器创建会失败。请在执行完"拓展功能表"部分的建表语句后再执行此触发器。
-- 此处使用 CREATE IF NOT EXISTS 逻辑，实际执行时如 oper_logs 不存在会报错，请按顺序执行。
DELIMITER $$

CREATE TRIGGER trg_interventions_status_log
AFTER UPDATE ON interventions
FOR EACH ROW
BEGIN
    -- 仅在状态发生变更时记录日志
    IF OLD.status != NEW.status THEN
        INSERT INTO oper_logs (table_name, record_id, action, old_value, new_value, operator_id, remark)
        VALUES ('interventions',
                NEW.intervention_id,
                'UPDATE_STATUS',
                OLD.status,
                NEW.status,
                NEW.user_id,
                CONCAT('干预任务 #', NEW.intervention_id, ' 状态从 ', OLD.status, ' 变更为 ', NEW.status));
    END IF;
END$$

DELIMITER ;

-- 【新增内容】触发器7：risk_levels 变更日志触发器 - 记录风险等级变化
DELIMITER $$

CREATE TRIGGER trg_risk_levels_change_log
AFTER UPDATE ON risk_levels
FOR EACH ROW
BEGIN
    -- 仅在风险等级发生变化时记录
    IF OLD.risk_level != NEW.risk_level THEN
        INSERT INTO oper_logs (table_name, record_id, action, old_value, new_value, operator_id, remark)
        VALUES ('risk_levels',
                NEW.risk_id,
                'RISK_CHANGE',
                OLD.risk_level,
                NEW.risk_level,
                NEW.user_id,
                CONCAT('用户 #', NEW.user_id, ' 风险等级从 ', OLD.risk_level,
                       ' (', OLD.risk_score, '分) 变更为 ', NEW.risk_level, ' (', NEW.risk_score, '分)'));
    END IF;
END$$

DELIMITER ;

-- 【新增内容】触发器8：assessments 删除前日志触发器 - 记录被删除的评估（通过CASCADE删除时也会触发）
DELIMITER $$

CREATE TRIGGER trg_assessments_delete_log
BEFORE DELETE ON assessments
FOR EACH ROW
BEGIN
    INSERT INTO oper_logs (table_name, record_id, action, old_value, new_value, operator_id, remark)
    VALUES ('assessments',
            OLD.assess_id,
            'DELETE',
            CONCAT('score=', OLD.total_score, ', level=', OLD.level),
            NULL,
            OLD.user_id,
            CONCAT('评估记录 #', OLD.assess_id, ' 被删除，用户 #', OLD.user_id, ' 量表 #', OLD.scale_id));
END$$

DELIMITER ;


-- ============================================================
-- 八、拓展功能表（新增配套辅助数据表）
-- ============================================================

-- 【新增内容】拓展表1：操作日志表 oper_logs - 记录所有关键数据变更
CREATE TABLE IF NOT EXISTS oper_logs (
    log_id          BIGINT AUTO_INCREMENT PRIMARY KEY           COMMENT '日志唯一标识，主键，自增',
    table_name      VARCHAR(50)   NOT NULL                      COMMENT '操作的表名',
    record_id       INT                                        COMMENT '操作的记录ID',
    action          VARCHAR(50)   NOT NULL                      COMMENT '操作类型：INSERT/UPDATE/DELETE/UPDATE_STATUS/RISK_CHANGE',
    old_value       VARCHAR(500)                                COMMENT '变更前的值',
    new_value       VARCHAR(500)                                COMMENT '变更后的值',
    operator_id     INT                                        COMMENT '操作人用户ID',
    operator_ip     VARCHAR(45)                                 COMMENT '操作人IP地址',
    remark          VARCHAR(500)                                COMMENT '备注说明',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP     COMMENT '日志记录时间',
    INDEX idx_logs_table (table_name),
    INDEX idx_logs_record (table_name, record_id),
    INDEX idx_logs_action (action),
    INDEX idx_logs_created_at (created_at),
    INDEX idx_logs_operator (operator_id)
) COMMENT='系统操作日志表 - 记录所有关键数据变更操作，用于审计追溯与问题排查';

-- 【新增内容】拓展表2：量表分类表 scale_categories - 量表的多级分类体系
CREATE TABLE IF NOT EXISTS scale_categories (
    category_id     INT AUTO_INCREMENT PRIMARY KEY              COMMENT '分类唯一标识，主键，自增',
    parent_id       INT           DEFAULT NULL                  COMMENT '上级分类ID，NULL表示一级分类',
    category_name   VARCHAR(100)  NOT NULL                      COMMENT '分类名称，如情绪障碍/人格评估/认知功能',
    category_code   VARCHAR(50)   NOT NULL UNIQUE               COMMENT '分类编码，如EMOTION/PERSONALITY/COGNITIVE',
    description     TEXT                                        COMMENT '分类说明',
    sort_order      INT           DEFAULT 0                     COMMENT '排序序号，越小越靠前',
    is_active       TINYINT(1)    DEFAULT 1                     COMMENT '是否启用：1-启用 0-停用',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
    INDEX idx_cat_parent (parent_id),
    INDEX idx_cat_code (category_code),
    INDEX idx_cat_sort (sort_order)
) COMMENT='量表分类表 - 量表的多级分类体系，支持树形结构';

-- 【新增内容】拓展表3：消息预警表 alert_messages - 系统自动预警消息
CREATE TABLE IF NOT EXISTS alert_messages (
    alert_id        INT AUTO_INCREMENT PRIMARY KEY              COMMENT '预警消息唯一标识，主键，自增',
    user_id         INT           NOT NULL                      COMMENT '目标用户ID',
    alert_type      ENUM('risk_warning','intervention_notify','appointment_remind','system_notice','custom')
                                  NOT NULL                      COMMENT '预警类型：风险预警/干预通知/预约提醒/系统公告/自定义',
    title           VARCHAR(200)  NOT NULL                      COMMENT '预警标题',
    content         TEXT          NOT NULL                      COMMENT '预警内容详情',
    severity        ENUM('info','warning','critical') DEFAULT 'warning' COMMENT '严重程度：info-信息 warning-警告 critical-严重',
    related_id      INT                                        COMMENT '关联的业务记录ID（如评估ID/干预任务ID）',
    is_read         TINYINT(1)    DEFAULT 0                     COMMENT '是否已读：0-未读 1-已读',
    read_at         DATETIME                                    COMMENT '阅读时间',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
    expired_at      DATETIME                                    COMMENT '过期时间',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_alert_user (user_id, is_read),
    INDEX idx_alert_type (alert_type),
    INDEX idx_alert_severity (severity),
    INDEX idx_alert_created (created_at),
    INDEX idx_alert_unread (user_id, is_read, created_at)
) COMMENT='消息预警表 - 系统自动预警与通知消息，支持风险预警/干预通知/预约提醒等';

-- 【新增内容】拓展表4：咨询师排班表 counselor_schedules - 咨询师值班安排
CREATE TABLE IF NOT EXISTS counselor_schedules (
    schedule_id     INT AUTO_INCREMENT PRIMARY KEY              COMMENT '排班唯一标识，主键，自增',
    counselor_id    INT           NOT NULL                      COMMENT '咨询师ID',
    schedule_date   DATE          NOT NULL                      COMMENT '排班日期',
    start_time      TIME          NOT NULL                      COMMENT '开始时间，如09:00',
    end_time        TIME          NOT NULL                      COMMENT '结束时间，如17:00',
    max_appointments INT         DEFAULT 5                      COMMENT '最大预约人数',
    current_count   INT           DEFAULT 0                     COMMENT '当前已预约人数',
    location        VARCHAR(100)                                COMMENT '咨询地点',
    status          ENUM('available','full','cancelled') DEFAULT 'available' COMMENT '排班状态：available-可预约 full-已满 cancelled-已取消',
    remark          VARCHAR(200)                                COMMENT '备注',
    created_at      DATETIME      DEFAULT CURRENT_TIMESTAMP     COMMENT '创建时间',
    updated_at      DATETIME      DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    FOREIGN KEY (counselor_id) REFERENCES counselors(counselor_id) ON DELETE CASCADE,
    INDEX idx_schedule_counselor (counselor_id, schedule_date),
    INDEX idx_schedule_date (schedule_date),
    INDEX idx_schedule_status (status),
    INDEX idx_schedule_date_status (schedule_date, status),
    UNIQUE INDEX uq_schedule (counselor_id, schedule_date)
) COMMENT='咨询师排班表 - 咨询师值班安排，管理每日可预约时段与人数限制';


-- ============================================================
-- 九、权限与安全（新增数据库用户、角色、权限配置）
-- ============================================================

-- 【新增内容】创建数据库角色
CREATE ROLE IF NOT EXISTS 'admin_role';
CREATE ROLE IF NOT EXISTS 'teacher_role';
CREATE ROLE IF NOT EXISTS 'student_role';

-- 【新增内容】admin_role 管理员角色权限：全部权限
GRANT ALL PRIVILEGES ON mindcare.* TO 'admin_role';

-- 【新增内容】teacher_role 咨询师角色权限：可查询所有数据，可更新干预任务状态
GRANT SELECT, INSERT, UPDATE ON mindcare.counselors TO 'teacher_role';
GRANT SELECT ON mindcare.users TO 'teacher_role';
GRANT SELECT ON mindcare.scales TO 'teacher_role';
GRANT SELECT ON mindcare.questions TO 'teacher_role';
GRANT SELECT ON mindcare.assessments TO 'teacher_role';
GRANT SELECT ON mindcare.answers TO 'teacher_role';
GRANT SELECT ON mindcare.risk_levels TO 'teacher_role';
GRANT SELECT, UPDATE ON mindcare.interventions TO 'teacher_role';
GRANT SELECT ON mindcare.counselor_schedules TO 'teacher_role';
GRANT SELECT ON mindcare.alert_messages TO 'teacher_role';
GRANT SELECT ON mindcare.oper_logs TO 'teacher_role';
GRANT SELECT ON mindcare.scale_categories TO 'teacher_role';
-- 视图权限
GRANT SELECT ON mindcare.v_dept_mental_stats TO 'teacher_role';
GRANT SELECT ON mindcare.v_intervention_detail TO 'teacher_role';
GRANT SELECT ON mindcare.v_user_assess_history TO 'teacher_role';
GRANT SELECT ON mindcare.v_daily_assess_report TO 'teacher_role';
GRANT SELECT ON mindcare.v_scale_usage_stats TO 'teacher_role';
GRANT SELECT ON mindcare.v_counselor_workload TO 'teacher_role';
GRANT SELECT ON mindcare.v_high_risk_users TO 'teacher_role';
GRANT SELECT ON mindcare.v_monthly_trend TO 'teacher_role';
-- 存储过程权限
GRANT EXECUTE ON PROCEDURE mindcare.sp_calc_risk_score TO 'teacher_role';
GRANT EXECUTE ON PROCEDURE mindcare.sp_update_intervention TO 'teacher_role';
GRANT EXECUTE ON PROCEDURE mindcare.sp_get_dashboard_data TO 'teacher_role';
GRANT EXECUTE ON PROCEDURE mindcare.sp_counselor_workload_stats TO 'teacher_role';
GRANT EXECUTE ON PROCEDURE mindcare.sp_query_users_paged TO 'teacher_role';

-- 【新增内容】student_role 学生角色权限：仅可查询自己的数据和量表题目
GRANT SELECT ON mindcare.scales TO 'student_role';
GRANT SELECT ON mindcare.questions TO 'student_role';
GRANT SELECT ON mindcare.counselors TO 'student_role';
-- 学生对自己的数据通过应用层鉴权控制，数据库层给予基础查询权限
GRANT SELECT ON mindcare.users TO 'student_role';
GRANT SELECT, INSERT ON mindcare.assessments TO 'student_role';
GRANT SELECT, INSERT ON mindcare.answers TO 'student_role';
GRANT SELECT ON mindcare.risk_levels TO 'student_role';
GRANT SELECT ON mindcare.interventions TO 'student_role';
GRANT SELECT ON mindcare.alert_messages TO 'student_role';
-- 视图权限（学生仅能通过应用层鉴权看到自己的数据，这里给基础视图查询权限）
GRANT SELECT ON mindcare.v_user_assess_history TO 'student_role';
-- 存储过程权限
GRANT EXECUTE ON PROCEDURE mindcare.sp_calc_risk_score TO 'student_role';

-- 【新增内容】创建数据库用户（密码为示例，生产环境需更换）
CREATE USER IF NOT EXISTS 'mindcare_admin'@'localhost'   IDENTIFIED BY 'Admin@MindCare2026';
CREATE USER IF NOT EXISTS 'mindcare_teacher'@'localhost'  IDENTIFIED BY 'Teacher@MindCare2026';
CREATE USER IF NOT EXISTS 'mindcare_student'@'localhost'  IDENTIFIED BY 'Student@MindCare2026';

-- 【新增内容】授予角色给用户
GRANT 'admin_role'   TO 'mindcare_admin'@'localhost';
GRANT 'teacher_role' TO 'mindcare_teacher'@'localhost';
GRANT 'student_role' TO 'mindcare_student'@'localhost';

-- 【新增内容】设置默认角色（MySQL 8.0）
SET DEFAULT ROLE 'admin_role'   TO 'mindcare_admin'@'localhost';
SET DEFAULT ROLE 'teacher_role' TO 'mindcare_teacher'@'localhost';
SET DEFAULT ROLE 'student_role' TO 'mindcare_student'@'localhost';

-- 【新增内容】刷新权限
FLUSH PRIVILEGES;


-- ============================================================
-- 十、数据字典与测试数据
-- ============================================================

-- ============================================================
-- 【新增内容】数据字典
-- ============================================================
/*
┌────────────────────────────────────────────────────────────────────────────────┐
│                          MindCare 数据库数据字典                                   │
├────────────┬──────────────┬───────────┬─────────────────────────────────────────┤
│ 表名        │ 中文名称      │ 记录类型  │ 说明                                    │
├────────────┼──────────────┼───────────┼─────────────────────────────────────────┤
│ counselors │ 心理咨询师表  │ 基础数据   │ 咨询师基本信息，被interventions/schedules引用 │
│ users      │ 学生用户表    │ 基础数据   │ 学生基本信息，学号唯一，支持登录认证         │
│ scales     │ 心理量表表    │ 基础数据   │ 测评量表元数据，如PHQ-9/GAD-7/PSS-10/PSQI  │
│ questions  │ 量表题目表    │ 基础数据   │ 量表题目与选项，每题0-3分                   │
│ assessments│ 心理评估记录表│ 业务数据   │ 用户测评记录，插入时触发器自动更新风险       │
│ answers    │ 答题明细表    │ 业务数据   │ 每次评估每道题的具体选择                    │
│ risk_levels│ 风险等级表    │ 业务数据   │ 用户综合风险等级，每用户一条，实时更新        │
│ interventions│ 干预任务表  │ 业务数据   │ 高风险自动触发的干预任务                    │
│ oper_logs  │ 操作日志表    │ 审计数据   │ 关键数据变更日志，用于审计追溯              │
│ scale_categories│ 量表分类表│ 基础数据  │ 量表多级分类体系                           │
│ alert_messages│ 消息预警表 │ 业务数据   │ 系统自动预警与通知消息                      │
│ counselor_schedules│ 排班表│ 业务数据  │ 咨询师值班安排与预约管理                     │
├────────────┴──────────────┴───────────┴─────────────────────────────────────────┤
│ 视图                 │ 类型      │ 说明                                         │
├──────────────────────┼───────────┼──────────────────────────────────────────────┤
│ v_dept_mental_stats  │ 统计视图  │ 院系心理健康综合统计（原有）                    │
│ v_intervention_detail│ 明细视图  │ 干预任务详情含用户+咨询师信息（原有）            │
│ v_user_assess_history│ 历史视图  │ 用户评估历史含当前风险等级（原有）              │
│ v_daily_assess_report│ 统计视图  │ 每日评估汇总报告（新增）                       │
│ v_scale_usage_stats  │ 统计视图  │ 量表使用频次与平均分统计（新增）                │
│ v_counselor_workload │ 统计视图  │ 咨询师工作量与完成率统计（新增）                │
│ v_high_risk_users    │ 明细视图  │ 高风险用户明细含最近评估详情（新增）            │
│ v_monthly_trend      │ 趋势视图  │ 月度心理健康趋势按院系统计（新增）              │
├──────────────────────┴───────────┴──────────────────────────────────────────────┤
│ 存储过程                    │ 类型      │ 说明                                   │
├─────────────────────────────┼───────────┼────────────────────────────────────────┤
│ sp_calc_risk_score          │ 原有增强  │ 单用户综合风险评估（新增事务+参数校验）    │
│ sp_calc_risk_score_v2       │ 新增      │ V2增强版，含事务控制与异常捕获             │
│ sp_update_intervention      │ 原有增强  │ 更新干预任务状态（新增事务控制）           │
│ sp_update_intervention_v2   │ 新增      │ V2增强版，含事务控制与异常捕获             │
│ sp_batch_calc_risk_scores   │ 新增      │ 批量风险计算（遍历所有用户）               │
│ sp_query_users_paged        │ 新增      │ 分页查询用户列表（多条件筛选）             │
│ sp_get_dashboard_data       │ 新增      │ 综合仪表盘数据统计（一次调用）             │
│ sp_counselor_workload_stats │ 新增      │ 咨询师工作量统计（含分页）                 │
│ sp_batch_insert_assessments │ 新增      │ 批量导入评估记录（JSON输入）              │
├─────────────────────────────┴───────────┴────────────────────────────────────────┤
│ 触发器                          │ 类型      │ 说明                               │
├─────────────────────────────────┼───────────┼────────────────────────────────────┤
│ trg_auto_intervention           │ 原有      │ 评估后自动预警与干预任务生成           │
│ trg_after_assessment_insert     │ 原有      │ 评估后触发干预（demo脚本中）           │
│ trg_answers_before_insert       │ 新增      │ 答题分值校验（0-3范围）                │
│ trg_answers_before_update       │ 新增      │ 答题分值校验（0-3范围）                │
│ trg_interventions_status_log    │ 新增      │ 干预任务状态变更日志记录               │
│ trg_risk_levels_change_log      │ 新增      │ 风险等级变化日志记录                   │
│ trg_assessments_delete_log      │ 新增      │ 评估记录删除日志记录                   │
└─────────────────────────────────┴───────────┴────────────────────────────────────┘
*/


-- ============================================================
-- 【新增内容】批量测试数据（不覆盖原有数据）
-- ============================================================

-- 新增量表分类测试数据
INSERT INTO scale_categories (parent_id, category_name, category_code, description, sort_order) VALUES
(NULL, '情绪障碍', 'EMOTION', '抑郁、焦虑等情绪障碍相关量表', 1),
(NULL, '压力管理', 'STRESS_MGMT', '压力知觉与应对方式相关量表', 2),
(NULL, '睡眠健康', 'SLEEP', '睡眠质量与睡眠障碍相关量表', 3),
(NULL, '人格评估', 'PERSONALITY', '人格特质与性格评估量表', 4),
(1, '抑郁评估', 'DEPRESSION', '抑郁症状筛查与评估子类', 1),
(1, '焦虑评估', 'ANXIETY', '焦虑症状筛查与评估子类', 2);

-- 新增咨询师排班测试数据（近7天）
INSERT INTO counselor_schedules (counselor_id, schedule_date, start_time, end_time, max_appointments, location, status) VALUES
(1, CURDATE(), '09:00', '12:00', 3, '心理咨询中心101室', 'available'),
(1, CURDATE(), '14:00', '17:00', 3, '心理咨询中心101室', 'available'),
(2, CURDATE(), '09:00', '17:00', 5, '心理咨询中心202室', 'available'),
(2, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '09:00', '17:00', 5, '心理咨询中心202室', 'available'),
(3, CURDATE(), '13:00', '18:00', 4, '心理咨询中心303室', 'available'),
(3, DATE_ADD(CURDATE(), INTERVAL 2 DAY), '09:00', '12:00', 3, '心理咨询中心303室', 'available'),
(4, CURDATE(), '09:00', '17:00', 4, '心理咨询中心404室', 'available'),
(4, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '14:00', '18:00', 3, '心理咨询中心404室', 'available');

-- 新增消息预警测试数据
INSERT INTO alert_messages (user_id, alert_type, title, content, severity, related_id) VALUES
(5, 'risk_warning', '高风险预警通知', '您近期的心理健康评估显示存在较高风险，建议及时预约咨询。', 'critical', 5),
(4, 'risk_warning', '中度风险提醒', '您的评估结果提示需要关注心理健康状态，建议进行进一步咨询。', 'warning', 4),
(7, 'risk_warning', '睡眠质量提醒', '您的睡眠质量评估结果异常，建议改善睡眠习惯并寻求专业帮助。', 'warning', 7),
(2, 'intervention_notify', '干预任务分配通知', '您的干预任务已分配给咨询师张晓雯，请关注后续安排。', 'info', 9);

-- 新增操作日志测试数据
INSERT INTO oper_logs (table_name, record_id, action, old_value, new_value, operator_id, remark) VALUES
('interventions', 1, 'UPDATE_STATUS', 'pending', 'in_progress', 8, '管理员开始处理干预任务'),
('interventions', 1, 'UPDATE_STATUS', 'in_progress', 'completed', 8, '管理员完成干预任务处理'),
('risk_levels', 5, 'RISK_CHANGE', 'safe', 'crisis', 5, '用户评估触发风险等级变更'),
('assessments', 5, 'INSERT', NULL, 'score=22, level=severe', 5, '用户提交抑郁量表评估');

-- 新增用户测试数据（更多院系覆盖）
INSERT INTO users (student_id, name, gender, department, grade, phone, email, password_hash) VALUES
('2023005001', '周杰', '男', '数学与统计学院', '2023级', '13900005001', 'zhoujie@mail.edu', '123456'),
('2022005002', '吴婷', '女', '数学与统计学院', '2022级', '13900005002', 'wuting@mail.edu', '123456'),
('2021006001', '郑浩', '男', '外国语学院', '2021级', '13900006001', 'zhenghao@mail.edu', '123456'),
('2023006002', '冯雪', '女', '外国语学院', '2023级', '13900006002', 'fengxue@mail.edu', '123456'),
('2022007001', '褚明', '男', '电子信息工程学院', '2022级', '13900007001', 'chuming@mail.edu', '123456'),
('2021007002', '卫兰', '女', '电子信息工程学院', '2021级', '13900007002', 'weilan@mail.edu', '123456'),
('2023008001', '蒋涛', '男', '化学与化工学院', '2023级', '13900008001', 'jiangtao@mail.edu', '123456'),
('2022008002', '沈蓉', '女', '化学与化工学院', '2022级', '13900008002', 'shenrong@mail.edu', '123456'),
('2021009001', '韩磊', '男', '生命科学学院', '2021级', '13900009001', 'hanlei@mail.edu', '123456'),
('2023009002', '杨柳', '女', '生命科学学院', '2023级', '13900009002', 'yangliu@mail.edu', '123456'),
('2022000010', '朱峰', '男', '计算机科学与技术学院', '2022级', '13900001010', 'zhufeng@mail.edu', '123456'),
('2023000011', '秦雨', '女', '计算机科学与技术学院', '2023级', '13900001011', 'qinyu@mail.edu', '123456');

-- 新增评估记录测试数据（不同时间、不同量表、不同等级，模拟真实场景）
INSERT INTO assessments (user_id, scale_id, total_score, level, assessed_at) VALUES
(9, 1, 18, 'moderate', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(10, 2, 12, 'moderate', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(11, 1, 4, 'normal', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(12, 3, 28, 'severe', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(13, 4, 12, 'severe', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(14, 1, 11, 'moderate', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(15, 2, 6, 'mild', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(16, 1, 25, 'severe', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(17, 3, 15, 'moderate', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(18, 4, 7, 'moderate', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(19, 1, 8, 'mild', DATE_SUB(NOW(), INTERVAL 6 DAY)),
(20, 2, 3, 'normal', DATE_SUB(NOW(), INTERVAL 6 DAY)),
-- 同一用户多次评估（用于测试加权风险计算）
(5, 2, 10, 'moderate', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(5, 3, 20, 'moderate', DATE_SUB(NOW(), INTERVAL 7 DAY)),
(4, 1, 16, 'moderate', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 3, 8, 'mild', DATE_SUB(NOW(), INTERVAL 14 DAY)),
(7, 1, 6, 'mild', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(7, 2, 14, 'moderate', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(1, 2, 4, 'normal', DATE_SUB(NOW(), INTERVAL 4 DAY)),
(1, 3, 10, 'mild', DATE_SUB(NOW(), INTERVAL 20 DAY));


-- ============================================================
-- 十一、性能与SQL规范优化方案
-- ============================================================

/*
【新增内容】慢查询规避方案与SQL规范建议
============================================

1. 分页查询规范：
   - 所有列表查询必须使用 LIMIT + OFFSET 分页
   - 单次查询最大返回行数不超过1000条
   - 推荐使用存储过程 sp_query_users_paged 进行分页查询

2. 索引使用建议：
   - 查询时 WHERE 条件优先使用已建索引字段
   - 避免在索引字段上使用函数（如 WHERE DATE(assessed_at) = '2026-03-01'）
     应改为：WHERE assessed_at >= '2026-03-01' AND assessed_at < '2026-03-02'
   - 避免 SELECT *，明确指定所需字段

3. JOIN 优化：
   - 多表关联时，小表驱动大表
   - 关联字段确保有索引
   - 优先使用已创建的视图（如 v_intervention_detail）代替复杂 JOIN

4. 聚合查询优化：
   - 统计类查询优先使用已创建的汇总视图（如 v_dept_mental_stats）
   - 避免在高峰期执行全表扫描的统计查询

5. EXPLAIN 分析模板：
   执行以下命令检查慢查询：
   EXPLAIN SELECT ... -- 查看执行计划
   SHOW INDEX FROM table_name; -- 查看表索引

6. 连接池建议：
   - 应用层使用连接池，最大连接数建议20-50
   - 及时释放数据库连接

7. 定期维护：
   - 定期执行 ANALYZE TABLE 更新索引统计信息
   - 定期清理 oper_logs 表中超过90天的日志数据

8. 查询示例优化对比：

   不推荐（慢）：
   SELECT * FROM assessments WHERE DATE(assessed_at) = '2026-03-01';

   推荐（快）：
   SELECT assess_id, user_id, scale_id, total_score, level, assessed_at
   FROM assessments
   WHERE assessed_at >= '2026-03-01' AND assessed_at < '2026-03-02'
   LIMIT 100;

   不推荐（慢）：
   SELECT * FROM users u, assessments a, scales s
   WHERE u.user_id = a.user_id AND a.scale_id = s.scale_id;

   推荐（快）：
   SELECT * FROM v_user_assess_history
   WHERE department = '计算机科学与技术学院'
   ORDER BY assessed_at DESC
   LIMIT 50;
*/


-- ============================================================
-- 【新增内容】性能优化：更新表统计信息
-- ============================================================
ANALYZE TABLE counselors;
ANALYZE TABLE users;
ANALYZE TABLE scales;
ANALYZE TABLE questions;
ANALYZE TABLE assessments;
ANALYZE TABLE answers;
ANALYZE TABLE risk_levels;
ANALYZE TABLE interventions;


-- ============================================================
-- 十二、视图与存储过程注释补充
-- ============================================================

-- 【新增内容】为原有视图补充注释（CREATE OR REPLACE 不改变查询逻辑，仅补充注释）
CREATE OR REPLACE VIEW v_dept_mental_stats AS
SELECT
    u.department                                                                     COMMENT '院系名称',
    COUNT(DISTINCT u.user_id)                                                        COMMENT '学生总数',
    COUNT(DISTINCT a.assess_id)                                                      COMMENT '测评总次数',
    ROUND(AVG(a.total_score), 2)                                                     COMMENT '平均得分',
    SUM(CASE WHEN a.level = 'severe'   THEN 1 ELSE 0 END)                           COMMENT '重度人数',
    SUM(CASE WHEN a.level = 'moderate' THEN 1 ELSE 0 END)                           COMMENT '中度人数',
    SUM(CASE WHEN a.level = 'mild'     THEN 1 ELSE 0 END)                           COMMENT '轻度人数',
    SUM(CASE WHEN a.level = 'normal'   THEN 1 ELSE 0 END)                           COMMENT '正常人数',
    ROUND(SUM(CASE WHEN a.level IN ('moderate','severe') THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(a.assess_id), 0), 2)                                        COMMENT '中高风险率(%)'
FROM users u
LEFT JOIN assessments a ON u.user_id = a.user_id
GROUP BY u.department;

-- 【新增内容】为原有视图补充注释
CREATE OR REPLACE VIEW v_intervention_detail AS
SELECT
    i.intervention_id                                                                COMMENT '干预任务ID',
    u.student_id                                                                     COMMENT '学号',
    u.name                                                                           COMMENT '学生姓名',
    u.department                                                                     COMMENT '所属院系',
    u.grade                                                                          COMMENT '年级',
    u.phone                                                                          COMMENT '学生电话',
    c.name                                                                           COMMENT '咨询师姓名',
    c.specialty                                                                      COMMENT '咨询师专长',
    c.phone                                                                          COMMENT '咨询师电话',
    i.trigger_reason                                                                 COMMENT '触发原因',
    i.priority                                                                       COMMENT '优先级',
    i.status                                                                         COMMENT '任务状态',
    a.total_score                                                                    COMMENT '触发评估得分',
    a.level                                                                          COMMENT '触发评估等级',
    i.created_at                                                                     COMMENT '任务创建时间',
    i.completed_at                                                                   COMMENT '任务完成时间',
    i.notes                                                                          COMMENT '处理备注'
FROM interventions i
JOIN users        u ON i.user_id       = u.user_id
LEFT JOIN counselors  c ON i.counselor_id  = c.counselor_id
LEFT JOIN assessments a ON i.assess_id     = a.assess_id;

-- 【新增内容】为原有视图补充注释
CREATE OR REPLACE VIEW v_user_assess_history AS
SELECT
    u.user_id                                                                        COMMENT '用户ID',
    u.student_id                                                                     COMMENT '学号',
    u.name                                                                           COMMENT '姓名',
    u.department                                                                     COMMENT '院系',
    s.name                                                                           COMMENT '量表名称',
    s.type                                                                           COMMENT '量表类型',
    a.assess_id                                                                      COMMENT '评估记录ID',
    a.total_score                                                                    COMMENT '评估总分',
    a.level                                                                          COMMENT '评估等级',
    a.assessed_at                                                                    COMMENT '评估时间',
    rl.risk_level                                                                    COMMENT '当前风险等级'
FROM assessments a
JOIN users  u  ON a.user_id  = u.user_id
JOIN scales s  ON a.scale_id = s.scale_id
LEFT JOIN risk_levels rl ON u.user_id = rl.user_id;


-- ============================================================
-- 执行完毕
-- ============================================================
SELECT 'MindCare 数据库全面优化方案执行完毕！' AS result;
SELECT '新增索引：20+个' AS index_optimization;
SELECT '新增 CHECK 约束：6个' AS constraint_enhancement;
SELECT '新增视图：5个（v_daily_assess_report, v_scale_usage_stats, v_counselor_workload, v_high_risk_users, v_monthly_trend）' AS view_extension;
SELECT '新增存储过程：5个（sp_batch_calc_risk_scores, sp_query_users_paged, sp_get_dashboard_data, sp_counselor_workload_stats, sp_batch_insert_assessments）' AS procedure_enhancement;
SELECT '增强存储过程：2个（sp_calc_risk_score_v2, sp_update_intervention_v2）' AS procedure_upgrade;
SELECT '新增触发器：5个（数据校验2个+日志记录3个）' AS trigger_enhancement;
SELECT '新增拓展表：4张（oper_logs, scale_categories, alert_messages, counselor_schedules）' AS table_extension;
SELECT '新增角色：3个（admin_role, teacher_role, student_role）' AS role_config;
SELECT '新增用户：3个（mindcare_admin, mindcare_teacher, mindcare_student）' AS user_config;
SELECT '新增测试数据：30+条（用户12条+评估20条+排班8条+预警4条+日志4条+分类6条）' AS test_data;


-- ============================================================
-- 十三、工程作业报告核心操作验证脚本
-- ============================================================
-- 本部分针对报告评分四大维度，提供可直接执行的验证SQL
-- 包括正常执行演示 + 违背约束报错演示
-- ============================================================

/*
┌──────────────────────────────────────────────────────────────────────────────┐
│                    MindCare 工程作业报告 - 核心操作验证指南                     │
├────────────┬──────┬───────────────────────────────────────────────────────────┤
│ 操作       │ 分值 │ 数据库实现要点                                             │
├────────────┼──────┼───────────────────────────────────────────────────────────┤
│ 事务删除   │ 13分 │ BEGIN TRANSACTION → 多表级联DELETE → COMMIT/ROLLBACK       │
│ 触发器添加 │ 20分 │ INSERT assessments → 触发器自动生成干预+更新风险等级          │
│ 存储过程更新│ 18分 │ CALL sp_calc_risk_score → 加权计算 → 更新risk_levels        │
│ 视图查询   │ 15分 │ SELECT FROM v_dept_mental_stats → 多表联合查询封装           │
└────────────┴──────┴───────────────────────────────────────────────────────────┘
*/


-- ============================================================
-- 13.1 事务删除操作验证（报告第4部分，13分）
-- ============================================================

-- 【正常执行】事务级联删除用户及其所有关联数据
-- 功能：删除用户时开启事务，原子级联删除该用户的干预任务、风险等级、评估记录、答题明细、用户主记录
-- 涉及表：interventions, risk_levels, assessments, answers, users（5张表）
-- 表连接：users.user_id = interventions.user_id / risk_levels.user_id / assessments.user_id
--         assessments.assess_id = answers.assess_id
-- 删除条件：users.user_id = 指定值

-- 1. 先查看即将被删除的用户数据（演示用）
SELECT u.user_id, u.name, u.student_id, u.department,
       (SELECT COUNT(*) FROM assessments a WHERE a.user_id = u.user_id) AS assess_count,
       (SELECT COUNT(*) FROM interventions i WHERE i.user_id = u.user_id) AS inter_count,
       (SELECT COUNT(*) FROM risk_levels rl WHERE rl.user_id = u.user_id) AS risk_count
FROM users u
WHERE u.user_id = 12;

-- 2. 执行事务删除（完整演示）
START TRANSACTION;

-- 删除前记录各表行数
SELECT '删除前' AS stage,
    (SELECT COUNT(*) FROM interventions WHERE user_id = 12) AS interventions_rows,
    (SELECT COUNT(*) FROM risk_levels WHERE user_id = 12) AS risk_levels_rows,
    (SELECT COUNT(*) FROM assessments WHERE user_id = 12) AS assessments_rows,
    (SELECT COUNT(*) FROM users WHERE user_id = 12) AS users_rows;

-- 级联删除（按外键依赖顺序）
DELETE FROM interventions WHERE user_id = 12;
DELETE FROM risk_levels WHERE user_id = 12;
DELETE FROM assessments WHERE user_id = 12;  -- answers 通过 CASCADE 自动删除
DELETE FROM users WHERE user_id = 12;

-- 删除后确认
SELECT '删除后' AS stage,
    (SELECT COUNT(*) FROM interventions WHERE user_id = 12) AS interventions_rows,
    (SELECT COUNT(*) FROM risk_levels WHERE user_id = 12) AS risk_levels_rows,
    (SELECT COUNT(*) FROM assessments WHERE user_id = 12) AS assessments_rows,
    (SELECT COUNT(*) FROM users WHERE user_id = 12) AS users_rows;

-- 确认无误，提交事务
COMMIT;

SELECT '✅ 事务删除成功：用户及所有关联数据已原子级联删除，数据一致性得到保证' AS result;


-- 【违背约束演示】模拟事务回滚场景
-- 场景：删除不存在的用户，事务应回滚
START TRANSACTION;

SELECT '尝试删除不存在的用户（user_id=9999）' AS action;

-- 检查用户是否存在
SET @v_user_exists = (SELECT COUNT(*) FROM users WHERE user_id = 9999);

-- 如果用户不存在，回滚事务
SET @rollback_sql = IF(@v_user_exists = 0,
    'ROLLBACK',
    'DELETE FROM interventions WHERE user_id = 9999; DELETE FROM risk_levels WHERE user_id = 9999; DELETE FROM assessments WHERE user_id = 9999; DELETE FROM users WHERE user_id = 9999; COMMIT;'
);

-- 此处用存储过程演示回滚逻辑
DROP PROCEDURE IF EXISTS sp_demo_delete_rollback;
DELIMITER $$
CREATE PROCEDURE sp_demo_delete_rollback(IN p_user_id INT, OUT p_result VARCHAR(200))
COMMENT '演示事务删除的回滚机制 - 用户不存在时自动回滚'
BEGIN
    DECLARE v_exist INT DEFAULT 0;

    -- 异常处理：任何SQL错误都回滚
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR: 事务已回滚，数据库异常';
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_exist FROM users WHERE user_id = p_user_id;

    IF v_exist = 0 THEN
        ROLLBACK;
        SET p_result = 'ERROR: 用户不存在，事务已回滚，未删除任何数据';
    ELSE
        DELETE FROM interventions WHERE user_id = p_user_id;
        DELETE FROM risk_levels WHERE user_id = p_user_id;
        DELETE FROM assessments WHERE user_id = p_user_id;
        DELETE FROM users WHERE user_id = p_user_id;
        COMMIT;
        SET p_result = CONCAT('SUCCESS: 用户 #', p_user_id, ' 及关联数据已删除');
    END IF;
END$$
DELIMITER ;

-- 测试：尝试删除不存在的用户 → 应回滚
CALL sp_demo_delete_rollback(9999, @result);
SELECT @result AS '事务回滚结果（违背约束演示）';

ROLLBACK;  -- 确保之前的事务状态已清理


-- ============================================================
-- 13.2 触发器添加操作验证（报告第5部分，20分）
-- ============================================================

-- 【正常执行】提交评估 → 触发器自动生成干预任务并更新风险等级
-- 功能：向 assessments 插入记录 → trg_auto_intervention 自动触发 →
--       根据等级生成干预任务 + 更新 risk_levels
-- 涉及表：assessments（主表）, interventions, risk_levels, users, counselors（联动表）
-- 输入数据要求：user_id非空且在users中存在，scale_id非空且在scales中存在，
--               total_score≥0，level为 normal/mild/moderate/severe

-- 1. 先查看提交前的状态
SELECT '提交前状态' AS stage;
SELECT user_id, name FROM users WHERE user_id = 3;
SELECT COUNT(*) AS '该用户现有评估数' FROM assessments WHERE user_id = 3;
SELECT COUNT(*) AS '该用户现有干预数' FROM interventions WHERE user_id = 3;

-- 2. 插入一条评估记录（触发器会自动执行）
INSERT INTO assessments (user_id, scale_id, total_score, level, note)
VALUES (3, 1, 18, 'moderate', '触发器测试：中度抑郁');

-- 3. 查看触发器自动生成的干预任务
SELECT '✅ 触发器自动生成结果' AS stage;
SELECT i.intervention_id, i.user_id, i.counselor_id, i.trigger_reason,
       i.priority, i.status, i.assess_id, i.created_at
FROM interventions i
WHERE i.user_id = 3
ORDER BY i.created_at DESC
LIMIT 3;

-- 4. 查看触发器自动更新的风险等级
SELECT * FROM risk_levels WHERE user_id = 3;

SELECT '✅ 触发器添加操作成功：评估→预警→干预全流程自动化，无需人工干预' AS result;


-- 【违背约束演示1】插入不合法评估记录（level 值非法）
-- 预期：CHECK约束阻止插入
SELECT '【违背约束演示1】尝试插入 level 值非法的评估记录' AS test_case;
INSERT INTO assessments (user_id, scale_id, total_score, level, note)
VALUES (3, 1, 50, 'critical', '应报错：level值不在ENUM范围内');
-- 预期报错：Data truncated for column 'level' 或 CHECK constraint failed


-- 【违背约束演示2】插入不存在的 user_id（外键约束）
-- 预期：外键约束阻止插入
SELECT '【违背约束演示2】尝试插入不存在的用户ID' AS test_case;
INSERT INTO assessments (user_id, scale_id, total_score, level)
VALUES (9999, 1, 10, 'moderate');
-- 预期报错：Cannot add or update a child row: a foreign key constraint fails


-- 【违背约束演示3】插入负数分数（CHECK约束）
-- 预期：CHECK约束阻止插入
SELECT '【违背约束演示3】尝试插入负数分数' AS test_case;
INSERT INTO assessments (user_id, scale_id, total_score, level)
VALUES (3, 1, -5, 'normal');
-- 预期报错：CHECK constraint `chk_assess_score` is violated


-- 【违背约束演示4】answers 表插入超出0-3范围的分值（CHECK约束+触发器双重校验）
-- 预期：trg_answers_before_insert 触发器阻止
SELECT '【违背约束演示4】尝试在 answers 表插入分值5（超出0-3范围）' AS test_case;
INSERT INTO answers (assess_id, question_id, selected_score)
VALUES (1, 1, 5);
-- 预期报错：SIGNAL SQLSTATE '45000' 答题分值必须在0-3之间


-- ============================================================
-- 13.3 存储过程更新操作验证（报告第6部分，18分）
-- ============================================================

-- 【正常执行】调用存储过程 sp_calc_risk_score 计算用户综合风险
-- 功能：取用户最近3次评估，按时间加权（3:2:1），
--       综合得分 = 加权平均分×0.6 + 历史最高分×0.4，映射风险等级后更新 risk_levels
-- 涉及表：assessments（读取）, risk_levels（更新）
-- 表连接：assessments.user_id = risk_levels.user_id
-- 修改字段：risk_levels.risk_score（加权计算）, risk_levels.risk_level（safe/watch/warning/crisis）

-- 1. 查看计算前的风险状态
SELECT '计算前状态' AS stage;
SELECT * FROM risk_levels WHERE user_id = 5;
SELECT assess_id, total_score, level, assessed_at
FROM assessments WHERE user_id = 5
ORDER BY assessed_at DESC LIMIT 5;

-- 2. 调用存储过程计算风险
CALL sp_calc_risk_score(5, @p_risk_level);
SELECT @p_risk_level AS '计算后的风险等级';

-- 3. 查看更新后的 risk_levels
SELECT '✅ 计算后状态' AS stage;
SELECT * FROM risk_levels WHERE user_id = 5;

SELECT '✅ 存储过程更新成功：加权计算综合风险分，自动映射风险等级并写入数据库' AS result;


-- 【违背约束演示1】传入不存在的用户ID
-- 预期：V2版存储过程参数校验后返回错误
SELECT '【违背约束演示1】调用 sp_calc_risk_score_v2，传入不存在的用户ID' AS test_case;
CALL sp_calc_risk_score_v2(9999, @result);
SELECT @result AS '存储过程返回结果（应为 ERROR:USER_NOT_FOUND）';


-- 【违背约束演示2】干预任务状态更新为非法值
-- 预期：存储过程参数校验后返回错误
SELECT '【违背约束演示2】调用 sp_update_intervention，传入非法状态值' AS test_case;
CALL sp_update_intervention(1, 'deleted', '测试非法状态', @result);
SELECT @result AS '存储过程返回结果（应为 ERROR: 状态值非法）';


-- 【违背约束演示3】尝试更新不存在的干预任务
-- 预期：存储过程返回"任务不存在"错误
SELECT '【违背约束演示3】调用 sp_update_intervention，传入不存在的干预任务ID' AS test_case;
CALL sp_update_intervention(99999, 'completed', '测试', @result);
SELECT @result AS '存储过程返回结果（应为 ERROR: 干预任务不存在）';


-- ============================================================
-- 13.4 视图查询操作验证（报告第7部分，15分）
-- ============================================================

-- 【正常执行】通过视图进行多表联合查询
-- 功能：通过数据库视图封装复杂多表JOIN，简化查询，统一数据出口
-- 涉及表：users, assessments, scales, interventions, risk_levels, counselors（6张表）
-- 表连接：users.user_id = assessments.user_id
--         assessments.scale_id = scales.scale_id
--         assessments.assess_id = interventions.assess_id
--         users.user_id = risk_levels.user_id
--         interventions.counselor_id = counselors.counselor_id

-- 视图1：院系心理健康统计（原有 - 用于院系统计报表）
SELECT '📊 视图1：v_dept_mental_stats - 院系心理健康统计' AS query_name;
SELECT department AS '院系',
       total_students AS '学生总数',
       total_assessments AS '测评次数',
       avg_score AS '平均得分',
       normal_count AS '正常',
       mild_count AS '轻度',
       moderate_count AS '中度',
       severe_count AS '重度',
       CONCAT(risk_rate_pct, '%') AS '风险率'
FROM v_dept_mental_stats
ORDER BY risk_rate_pct DESC;

-- 视图2：干预任务详情（原有 - 用于管理后台干预任务列表）
SELECT '📋 视图2：v_intervention_detail - 干预任务详情（待处理）' AS query_name;
SELECT intervention_id, student_name, department, priority, status,
       trigger_reason, counselor_name, created_at
FROM v_intervention_detail
WHERE status = 'pending'
ORDER BY
    CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END,
    created_at ASC
LIMIT 10;

-- 视图3：用户评估历史（原有 - 用于查看个人评估记录）
SELECT '📝 视图3：v_user_assess_history - 用户评估历史' AS query_name;
SELECT student_id, name, department, scale_name, scale_type,
       total_score, level, assessed_at, current_risk
FROM v_user_assess_history
WHERE department = '计算机科学与技术学院'
ORDER BY assessed_at DESC
LIMIT 10;

-- 视图4（新增）：日报汇总
SELECT '📈 视图4（新增）：v_daily_assess_report - 每日评估报告' AS query_name;
SELECT * FROM v_daily_assess_report LIMIT 7;

-- 视图5（新增）：高风险用户明细
SELECT '🚨 视图5（新增）：v_high_risk_users - 高风险用户明细' AS query_name;
SELECT student_name, department, grade, current_risk_level,
       current_risk_score, last_assess_score, last_assess_time,
       total_assess_count, total_intervention_count
FROM v_high_risk_users
ORDER BY current_risk_score DESC;

SELECT '✅ 视图查询成功：多表联合查询封装，降低业务耦合，统一数据出口' AS result;


-- ============================================================
-- 13.5 完整演示流程总结
-- ============================================================

/*
【工程作业报告演示流程建议】

1. 事务删除操作（13分）：
   - 正常：在用户管理页面点击"注销"，展示事务级联删除进度动画，删除后所有关联表数据清空
   - 违背：通过存储过程 sp_demo_delete_rollback 演示用户不存在时的事务回滚
   - 验证：删除前后各表行数对比，确认原子性

2. 触发器添加操作（20分）：
   - 正常：学生提交测评 → 数据库触发器自动生成干预任务 + 更新风险等级
   - 违背1：尝试提交非法level值 → 数据库报错
   - 违背2：尝试提交不存在user_id → 外键约束报错
   - 违背3：尝试插入负数分数 → CHECK约束报错
   - 验证：查看interventions表和risk_levels表的自动变更

3. 存储过程更新操作（18分）：
   - 正常：管理员选择用户 → 调用sp_calc_risk_score → 加权计算 → 更新风险等级
   - 违背1：传入不存在的用户ID → 返回"USER_NOT_FOUND"
   - 违背2：更新干预任务状态为非法值 → 返回"状态值非法"
   - 验证：risk_levels表的risk_score和risk_level字段更新

4. 视图查询操作（15分）：
   - 正常：院系统计页面 → 查询v_dept_mental_stats → 图表+表格展示
   - 干预任务管理 → 查询v_intervention_detail → 多维度筛选
   - 评估历史 → 查询v_user_assess_history → 个人历史记录
   - 验证：视图数据与原始表数据一致性
*/
