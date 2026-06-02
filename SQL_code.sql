-- ============================================================
-- MindCare 心理健康评估与干预平台 - 数据库初始化脚本
-- MySQL 8.0 | 数据库工程作业
-- ============================================================

CREATE DATABASE IF NOT EXISTS mindcare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE mindcare;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS interventions;
DROP TABLE IF EXISTS risk_levels;
DROP TABLE IF EXISTS answers;
DROP TABLE IF EXISTS assessments;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS scales;
DROP TABLE IF EXISTS counselors;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 1. 咨询师表（被参照表，先建）
-- ============================================================
CREATE TABLE counselors (
    counselor_id    INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(50)  NOT NULL COMMENT '姓名',
    gender          ENUM('男','女') DEFAULT '男',
    specialty       VARCHAR(100) NOT NULL COMMENT '专长领域',
    phone           VARCHAR(20),
    email           VARCHAR(100),
    available       TINYINT(1)   DEFAULT 1 COMMENT '是否在职',
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP
) COMMENT='心理咨询师表';

-- ============================================================
-- 2. 用户表（学生）
-- ============================================================
CREATE TABLE users (
    user_id         INT AUTO_INCREMENT PRIMARY KEY,
    student_id      VARCHAR(20)  NOT NULL UNIQUE COMMENT '学号',
    name            VARCHAR(50)  NOT NULL COMMENT '姓名',
    gender          ENUM('男','女') DEFAULT '男',
    department      VARCHAR(100) NOT NULL COMMENT '院系',
    grade           VARCHAR(20)  NOT NULL COMMENT '年级',
    phone           VARCHAR(20),
    email           VARCHAR(100),
    password_hash   VARCHAR(255) NOT NULL DEFAULT '123456',
    status          ENUM('active','inactive','banned') DEFAULT 'active',
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP
) COMMENT='学生用户表';

-- ============================================================
-- 3. 量表表
-- ============================================================
CREATE TABLE scales (
    scale_id        INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL COMMENT '量表名称',
    type            ENUM('depression','anxiety','stress','sleep','comprehensive') NOT NULL COMMENT '类型',
    description     TEXT COMMENT '量表说明',
    question_count  INT DEFAULT 0 COMMENT '题目数量',
    max_score       INT DEFAULT 0 COMMENT '满分',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='心理量表表';

-- ============================================================
-- 4. 题目表
-- ============================================================
CREATE TABLE questions (
    question_id     INT AUTO_INCREMENT PRIMARY KEY,
    scale_id        INT NOT NULL COMMENT '所属量表',
    seq_no          INT NOT NULL COMMENT '题号',
    content         TEXT NOT NULL COMMENT '题目内容',
    opt_0           VARCHAR(200) COMMENT '选项A(0分)',
    opt_1           VARCHAR(200) COMMENT '选项B(1分)',
    opt_2           VARCHAR(200) COMMENT '选项C(2分)',
    opt_3           VARCHAR(200) COMMENT '选项D(3分)',
    FOREIGN KEY (scale_id) REFERENCES scales(scale_id) ON DELETE CASCADE
) COMMENT='量表题目表';

-- ============================================================
-- 5. 评估记录表
-- ============================================================
CREATE TABLE assessments (
    assess_id       INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL COMMENT '用户ID',
    scale_id        INT NOT NULL COMMENT '量表ID',
    total_score     INT NOT NULL DEFAULT 0 COMMENT '总分',
    level           ENUM('normal','mild','moderate','severe') DEFAULT 'normal' COMMENT '评估结果等级',
    note            TEXT COMMENT '备注',
    assessed_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (scale_id) REFERENCES scales(scale_id)
) COMMENT='心理评估记录表';

-- ============================================================
-- 6. 答题明细表
-- ============================================================
CREATE TABLE answers (
    answer_id       INT AUTO_INCREMENT PRIMARY KEY,
    assess_id       INT NOT NULL COMMENT '评估记录ID',
    question_id     INT NOT NULL COMMENT '题目ID',
    selected_score  INT NOT NULL DEFAULT 0 COMMENT '选择的分值(0-3)',
    FOREIGN KEY (assess_id) REFERENCES assessments(assess_id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES questions(question_id)
) COMMENT='答题明细表';

-- ============================================================
-- 7. 风险等级表（每用户一条，实时更新）
-- ============================================================
CREATE TABLE risk_levels (
    risk_id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL UNIQUE COMMENT '用户ID',
    risk_score      DECIMAL(5,2) DEFAULT 0 COMMENT '综合风险分(0-100)',
    risk_level      ENUM('safe','watch','warning','crisis') DEFAULT 'safe' COMMENT '风险等级',
    last_assess_id  INT COMMENT '最近一次评估ID',
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (last_assess_id) REFERENCES assessments(assess_id) ON SET NULL
) COMMENT='用户综合风险等级表';

-- ============================================================
-- 8. 干预任务表
-- ============================================================
CREATE TABLE interventions (
    intervention_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT NOT NULL COMMENT '学生ID',
    counselor_id    INT COMMENT '咨询师ID',
    trigger_reason  VARCHAR(200) NOT NULL COMMENT '触发原因',
    assess_id       INT COMMENT '触发评估ID',
    priority        ENUM('low','medium','high','urgent') DEFAULT 'medium' COMMENT '优先级',
    status          ENUM('pending','in_progress','completed','cancelled') DEFAULT 'pending',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    completed_at    DATETIME,
    notes           TEXT COMMENT '处理备注',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (counselor_id) REFERENCES counselors(counselor_id) ON SET NULL,
    FOREIGN KEY (assess_id) REFERENCES assessments(assess_id) ON SET NULL
) COMMENT='心理干预任务表';


-- ============================================================
-- 触发器 1：评估结果自动预警触发器
-- 向assessments插入新记录后，若分数达到中重度阈值，
-- 自动向interventions插入紧急干预任务，并更新risk_levels
-- ============================================================
DELIMITER $$

CREATE TRIGGER trg_auto_intervention
AFTER INSERT ON assessments
FOR EACH ROW
BEGIN
    DECLARE v_level VARCHAR(20);
    DECLARE v_priority VARCHAR(20);
    DECLARE v_reason VARCHAR(200);
    DECLARE v_counselor_id INT;

    -- 根据等级设置优先级
    SET v_level = NEW.level;

    IF v_level = 'severe' THEN
        SET v_priority = 'urgent';
        SET v_reason = CONCAT('严重心理风险预警：评估得分 ', NEW.total_score, ' 分，达到重度等级，需紧急干预');
    ELSEIF v_level = 'moderate' THEN
        SET v_priority = 'high';
        SET v_reason = CONCAT('中度心理风险预警：评估得分 ', NEW.total_score, ' 分，建议及时关注');
    END IF;

    -- 仅中度及以上才触发干预任务
    IF v_level IN ('moderate', 'severe') THEN
        -- 自动分配空闲咨询师（选择接单最少的）
        SELECT counselor_id INTO v_counselor_id
        FROM counselors
        WHERE available = 1
        ORDER BY (SELECT COUNT(*) FROM interventions i WHERE i.counselor_id = counselors.counselor_id AND i.status IN ('pending','in_progress')) ASC
        LIMIT 1;

        -- 插入干预任务
        INSERT INTO interventions (user_id, counselor_id, trigger_reason, assess_id, priority, status)
        VALUES (NEW.user_id, v_counselor_id, v_reason, NEW.assess_id, v_priority, 'pending');

        -- 更新或插入风险等级
        INSERT INTO risk_levels (user_id, risk_score, risk_level, last_assess_id)
        VALUES (
            NEW.user_id,
            NEW.total_score,
            CASE v_level
                WHEN 'severe'   THEN 'crisis'
                WHEN 'moderate' THEN 'warning'
                ELSE 'watch'
            END,
            NEW.assess_id
        )
        ON DUPLICATE KEY UPDATE
            risk_score      = NEW.total_score,
            risk_level      = CASE v_level
                                  WHEN 'severe'   THEN 'crisis'
                                  WHEN 'moderate' THEN 'warning'
                                  ELSE 'watch'
                              END,
            last_assess_id  = NEW.assess_id,
            updated_at      = NOW();
    ELSE
        -- 正常/轻度：更新风险等级为安全/观察
        INSERT INTO risk_levels (user_id, risk_score, risk_level, last_assess_id)
        VALUES (
            NEW.user_id,
            NEW.total_score,
            CASE v_level WHEN 'mild' THEN 'watch' ELSE 'safe' END,
            NEW.assess_id
        )
        ON DUPLICATE KEY UPDATE
            risk_score      = NEW.total_score,
            risk_level      = CASE v_level WHEN 'mild' THEN 'watch' ELSE 'safe' END,
            last_assess_id  = NEW.assess_id,
            updated_at      = NOW();
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- 存储过程 1：综合风险评估存储过程
-- 取用户最近3次评估加权计算综合风险分，更新risk_levels
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_calc_risk_score(IN p_user_id INT, OUT p_risk_level VARCHAR(20))
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
        LEAVE sp_calc_risk_score;
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
END$$

DELIMITER ;


-- ============================================================
-- 存储过程 2：更新干预任务状态（完成/取消）
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_update_intervention(
    IN  p_intervention_id INT,
    IN  p_new_status      VARCHAR(20),
    IN  p_notes           TEXT,
    OUT p_result          VARCHAR(100)
)
BEGIN
    DECLARE v_exist INT DEFAULT 0;
    DECLARE v_user_id INT;

    SELECT COUNT(*), MAX(user_id) INTO v_exist, v_user_id
    FROM interventions WHERE intervention_id = p_intervention_id;

    IF v_exist = 0 THEN
        SET p_result = 'ERROR: 干预任务不存在';
    ELSEIF p_new_status NOT IN ('in_progress','completed','cancelled') THEN
        SET p_result = 'ERROR: 状态值非法';
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
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- 视图 1：院系心理健康综合统计视图
-- ============================================================
CREATE OR REPLACE VIEW v_dept_mental_stats AS
SELECT
    u.department,
    COUNT(DISTINCT u.user_id)                                           AS total_students,
    COUNT(DISTINCT a.assess_id)                                         AS total_assessments,
    ROUND(AVG(a.total_score), 2)                                        AS avg_score,
    SUM(CASE WHEN a.level = 'severe'   THEN 1 ELSE 0 END)              AS severe_count,
    SUM(CASE WHEN a.level = 'moderate' THEN 1 ELSE 0 END)              AS moderate_count,
    SUM(CASE WHEN a.level = 'mild'     THEN 1 ELSE 0 END)              AS mild_count,
    SUM(CASE WHEN a.level = 'normal'   THEN 1 ELSE 0 END)              AS normal_count,
    ROUND(SUM(CASE WHEN a.level IN ('moderate','severe') THEN 1 ELSE 0 END) * 100.0
          / NULLIF(COUNT(a.assess_id), 0), 2)                           AS risk_rate_pct
FROM users u
LEFT JOIN assessments a ON u.user_id = a.user_id
GROUP BY u.department;


-- ============================================================
-- 视图 2：干预任务详情视图（含用户+咨询师信息）
-- ============================================================
CREATE OR REPLACE VIEW v_intervention_detail AS
SELECT
    i.intervention_id,
    u.student_id,
    u.name          AS student_name,
    u.department,
    u.grade,
    u.phone         AS student_phone,
    c.name          AS counselor_name,
    c.specialty     AS counselor_specialty,
    c.phone         AS counselor_phone,
    i.trigger_reason,
    i.priority,
    i.status,
    a.total_score   AS trigger_score,
    a.level         AS trigger_level,
    i.created_at,
    i.completed_at,
    i.notes
FROM interventions i
JOIN users        u ON i.user_id       = u.user_id
LEFT JOIN counselors  c ON i.counselor_id  = c.counselor_id
LEFT JOIN assessments a ON i.assess_id     = a.assess_id;


-- ============================================================
-- 视图 3：用户评估历史视图
-- ============================================================
CREATE OR REPLACE VIEW v_user_assess_history AS
SELECT
    u.user_id,
    u.student_id,
    u.name,
    u.department,
    s.name          AS scale_name,
    s.type          AS scale_type,
    a.assess_id,
    a.total_score,
    a.level,
    a.assessed_at,
    rl.risk_level   AS current_risk
FROM assessments a
JOIN users  u  ON a.user_id  = u.user_id
JOIN scales s  ON a.scale_id = s.scale_id
LEFT JOIN risk_levels rl ON u.user_id = rl.user_id;
