const fs = require('fs');
const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, HeadingLevel, AlignmentType, BorderStyle, WidthType, ShadingType, PageBreak } = require('docx');

const B = { top: { style: BorderStyle.SINGLE, size: 1 }, bottom: { style: BorderStyle.SINGLE, size: 1 }, left: { style: BorderStyle.SINGLE, size: 1 }, right: { style: BorderStyle.SINGLE, size: 1 } };

function H1(t) { return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: t, bold: true, font: 'SimHei', size: 32 })], spacing: { before: 360, after: 180 } }); }
function H2(t) { return new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: t, bold: true, font: 'SimHei', size: 28 })], spacing: { before: 280, after: 140 } }); }
function H3(t) { return new Paragraph({ heading: HeadingLevel.HEADING_3, children: [new TextRun({ text: t, bold: true, font: 'SimHei', size: 24 })], spacing: { before: 200, after: 100 } }); }
function P(t, b) { return new Paragraph({ children: [new TextRun({ text: t, font: 'SimSun', size: 21, bold: !!b })], spacing: { after: 80, line: 340 } }); }
function BP(t) { return P(t, true); }
function E() { return new Paragraph({ spacing: { after: 80 } }); }
function PG() { return new Paragraph({ children: [new PageBreak()] }); }
function TC(t, o) {
  const c = Array.isArray(t) ? t.map(x => typeof x === 'string' ? new Paragraph({ children: [new TextRun({ text: x, font: 'SimSun', size: 20 })], spacing: { after: 30, line: 260 } }) : x) : [new Paragraph({ children: [new TextRun({ text: String(t), font: 'SimSun', size: 20 })], spacing: { after: 30, line: 260 } })];
  return new TableCell({ children: c, borders: B, width: o?.w ? { size: o.w, type: WidthType.PERCENTAGE } : undefined, shading: o?.sh ? { fill: o.sh, type: ShadingType.SOLID } : undefined, verticalAlign: 'center' });
}
function HC(t, w) { return TC(t, { w, sh: 'D9E2F3' }); }

// 代码块：用数组传入多行代码，避免引号冲突
function CODE(lines) {
  const arr = Array.isArray(lines) ? lines : [lines];
  return arr.map(l => new Paragraph({ children: [new TextRun({ text: l, font: 'Courier New', size: 18 })], spacing: { after: 40, line: 260 }, indent: { left: 360 } }));
}
function CODES(...args) { args.forEach(a => { if (Array.isArray(a)) a.forEach(x => C.push(x)); else C.push(a); }); }
function ADDP(x) { if (Array.isArray(x)) x.forEach(y => C.push(y)); else C.push(x); }

const C = [];

// ===== 封面 =====
C.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1000, after: 200 }, children: [new TextRun({ text: '数据库系统工程作业报告', bold: true, font: 'SimHei', size: 44 })] }));
C.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 500 }, children: [new TextRun({ text: 'MindCare 心理健康评估与干预管理系统', font: 'SimHei', size: 28, color: '4B5C6B' })] }));

// ===== 1. 项目信息 =====
C.push(H1('1. 项目信息（10分）'));
C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('学号', 15), TC('2410665', { w: 35 }), HC('姓名', 15), TC('殷佳仪', { w: 35 })] }),
  new TableRow({ children: [HC('专业', 15), TC('计算机科学与技术', { w: 85 })] }),
  new TableRow({ children: [HC('项目名称', 15), TC('MindCare 心理健康评估与干预管理系统', { w: 85 })] }),
  new TableRow({ children: [HC('必备环境', 15), TC('Windows 10/11 + MySQL 8.0 + Python 3.9+ + Flask + PyMySQL + Chart.js 4.4.0', { w: 85 })] }),
]}));
C.push(E());

C.push(H2('1.1 系统主要功能简介（4分）'));
C.push(P('本系统为B/S架构校园心理健康管理平台，采用前后端分离架构（Flask后端 + 原生HTML/CSS/JS前端），以MySQL 8.0作为后台数据库。系统面向高校学生心理健康管理场景，实现了以下核心功能：'));
C.push(P('（1）学生心理测评：支持PHQ-9抑郁量表、GAD-7焦虑量表、PSS-10压力知觉量表、PSQI匹兹堡睡眠质量指数量表共四种标准化心理测评量表。学生可在线逐题作答，实时显示得分，提交后结果自动存入数据库并触发风险评估与干预流程。'));
C.push(P('（2）风险自动判定：测评提交后，后端自动计算总分并判定等级（normal/mild/moderate/severe）。数据库触发器trg_auto_intervention在assessments表插入后自动执行，生成干预任务并更新risk_levels表，实现评估→预警→干预全流程自动化。'));
C.push(P('（3）干预任务管理：管理员可查看和管理触发器自动生成的干预任务，支持按状态筛选、优先级排序。通过存储过程sp_update_intervention更新任务状态，并自动联动调整用户风险等级。'));
C.push(P('（4）数据统计与可视化：基于8个数据库视图提供多维度数据分析——院系统计、干预详情、用户评估历史、每日评估报告、量表使用统计、咨询师工作量、高风险用户明细、月度趋势。前端使用Chart.js实现折线图、环形图、柱状图可视化。'));
C.push(P('（5）用户事务级联删除：管理员注销用户时通过数据库事务（BEGIN→DELETE×N→COMMIT/ROLLBACK）原子性删除users、assessments、answers、interventions、risk_levels共5张表的关联数据，保证数据一致性。'));
C.push(P('核心覆盖数据库四大操作：事务删除、触发器添加、存储过程更新、视图查询，将本学期数据库课程所学知识完整应用于实际开发。'));
C.push(E());

C.push(H2('1.2 系统主要页面截图（6分）'));
C.push(P('（系统截图占位——请在Word中插入以下页面截图）'));
C.push(P('① 系统登录页面：暗色主题，双角色登录，Token认证与登录态恢复'));
C.push(P('② 数据总览页面（管理员）：注册用户数、累计测评数、待处理干预数、高风险用户数、近7日趋势折线图、风险分布环形图'));
C.push(P('③ 用户管理页面（管理员）：学生列表含风险等级/分数，事务级联删除按钮'));
C.push(P('④ 干预任务管理页面（管理员）：触发器自动生成的任务列表，状态筛选与处理功能'));
C.push(P('⑤ 院系统计页面（管理员）：基于v_dept_mental_stats视图的柱状图、数据列表、详细分析三种视图'));
C.push(P('⑥ 心理测评页面（学生）：量表选择→逐题作答→实时得分→结果展示→干预提醒'));
C.push(P('⑦ 数据库操作演示页面：事务删除、触发器添加、存储过程更新、视图查询四大操作面板，含正常执行与违背约束双场景'));
C.push(PG());

// ===== 2. 系统配置 =====
C.push(H1('2. 系统配置（10分）'));
C.push(H2('2.1 系统配置说明（2分）'));
C.push(P('后台数据库：MySQL 8.0（大型关系型数据库管理系统，支持事务、触发器、存储过程、视图等高级特性）'));
C.push(P('高级语言：Python 3.9+，使用Flask Web框架作为后端服务器（app.py，共935行），pymysql作为MySQL驱动'));
C.push(P('前端技术：原生HTML5 + CSS3 + JavaScript（ES6，index.html共1995行），Chart.js 4.4.0实现数据可视化'));
C.push(E());

C.push(H2('2.2 配置步骤（2分）'));
C.push(BP('DBMS配置步骤：'));
C.push(P('① 安装MySQL 8.0，设置端口3306并启动MySQL服务'));
C.push(P('② 使用root账号登录MySQL'));
C.push(P('③ 创建数据库：CREATE DATABASE mindcare CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'));
C.push(P('④ 执行database/mindcare_init.sql脚本，创建8张数据表、1个触发器、2个存储过程、8个视图'));
C.push(P('⑤ 可选：执行MindCare_数据库优化方案.sql，添加索引优化、CHECK约束、拓展视图与存储过程'));
C.push(E());
C.push(BP('高级语言配置步骤：'));
C.push(P('① 安装Python 3.9或更高版本'));
C.push(P('② 安装Flask框架：pip install flask'));
C.push(P('③ 安装CORS支持：pip install flask-cors'));
C.push(P('④ 安装MySQL驱动：pip install pymysql'));
C.push(P('⑤ 确认app.py中DB_CONFIG与本地MySQL配置一致'));
C.push(P('⑥ 启动后端服务：python app.py（监听0.0.0.0:5000，debug模式）'));
C.push(P('⑦ 浏览器访问 http://localhost:5000'));
C.push(E());

C.push(H2('2.3 连接串分析（6分）'));
C.push(P('Python后端通过pymysql库连接MySQL数据库，连接配置位于app.py第85-93行：'));
C.push(...CODE([
  "DB_CONFIG = {",
  '    "host":      "localhost",        # 数据库服务器地址',
  '    "port":      3306,               # MySQL端口',
  '    "user":      "root",             # 数据库用户名',
  '    "password":  "123456",           # 数据库密码',
  '    "database":  "mindcare",         # 目标数据库名',
  '    "charset":   "utf8mb4",          # 字符编码',
  '    "cursorclass": pymysql.cursors.DictCursor',
  "}"
]));
C.push(E());

C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('序号', 5), HC('参数', 10), HC('功能说明', 55), HC('取值', 12), HC('分析', 18)] }),
  new TableRow({ children: [TC('1'), TC('host'), TC('数据库服务器地址。localhost代表本机连接，MySQL与后端程序运行在同一台电脑上，适合项目本地开发'), TC('localhost'), TC('本地回环地址')] }),
  new TableRow({ children: [TC('2'), TC('port'), TC('MySQL数据库服务监听端口'), TC('3306'), TC('MySQL默认端口')] }),
  new TableRow({ children: [TC('3'), TC('user'), TC('连接数据库的用户名。root拥有数据库的全部操作权限（增删改查、创建表、调用存储过程等），可完全支撑项目后端对数据库的所有操作需求'), TC('root'), TC('超级管理员')] }),
  new TableRow({ children: [TC('4'), TC('password'), TC('连接数据库的密码，与MySQL root用户密码一致'), TC('123456'), TC('开发环境密码')] }),
  new TableRow({ children: [TC('5'), TC('database'), TC('需要连接的数据库名称。明确连接到MindCare心理健康评估平台专用数据库，确保后端操作的表、视图、存储过程等对象都属于该项目'), TC('mindcare'), TC('项目专用库')] }),
  new TableRow({ children: [TC('6'), TC('charset'), TC('字符编码。utf8mb4支持完整Unicode（含中文和emoji），能保证学生姓名、测评答案、干预备注等文本数据不乱码，满足项目多类型文本存储需求'), TC('utf8mb4'), TC('完整UTF-8')] }),
]}));
C.push(E());
C.push(P('（连接串代码截图占位——请插入app.py第85-93行的截图）'));
C.push(E());
C.push(P('备注：本系统采用MySQL + Flask轻量高效架构，连接配置标准规范，字符集支持中文。数据库连接使用DictCursor返回字典格式数据，便于JSON序列化。同时实现了Token认证机制（SHA256哈希密码 + secrets.token_hex生成32位token + 24小时过期），兼容Cookie Session和Bearer Token双认证方式，解决了跨域和文件协议场景下的登录态问题。'));
C.push(PG());

// ===== 3. 数据库设计 =====
C.push(H1('3. 数据库设计（14分）'));
C.push(H2('3.1 数据表信息（10分）'));
C.push(P('按照数据表的创建顺序，依次给出所涉及数据表的信息。参照字段以"（字段1，字段2，……，字段n）"的形式给出，被参照字段以"表名（字段1，字段2，……，字段n）"的形式给出。'));
C.push(E());

C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('创建顺序', 6), HC('数据表名称', 13), HC('主键', 10), HC('参照属性（外键）', 25), HC('被参照表及属性', 25), HC('说明', 21)] }),
  new TableRow({ children: [TC('1'), TC('counselors\n（咨询师表）'), TC('counselor_id'), TC('\\'), TC('\\'), TC('被参照表，先建。存储咨询师姓名、性别、专长、联系方式及在职状态')] }),
  new TableRow({ children: [TC('2'), TC('users\n（用户表）'), TC('user_id'), TC('\\'), TC('risk_levels(user_id)\ninterventions(user_id)\nassessments(user_id)'), TC('学生用户表。学号唯一约束，密码SHA256哈希存储，支持登录认证')] }),
  new TableRow({ children: [TC('3'), TC('scales\n（量表表）'), TC('scale_id'), TC('\\'), TC('questions(scale_id)\nassessments(scale_id)'), TC('心理量表元数据。类型枚举：depression/anxiety/stress/sleep/comprehensive')] }),
  new TableRow({ children: [TC('4'), TC('questions\n（题目表）'), TC('question_id'), TC('（scale_id）'), TC('scales(scale_id)'), TC('量表题目与选项。每题0-3分，4个选项(opt_0~opt_3)，CASCADE级联删除')] }),
  new TableRow({ children: [TC('5'), TC('assessments\n（评估记录表）'), TC('assess_id'), TC('（user_id, scale_id）'), TC('users(user_id)\nscales(scale_id)'), TC('用户测评记录。插入后触发trg_auto_intervention触发器，等级：normal/mild/moderate/severe')] }),
  new TableRow({ children: [TC('6'), TC('answers\n（答题记录表）'), TC('answer_id'), TC('（assess_id, question_id）'), TC('assessments(assess_id)\nquestions(question_id)'), TC('答题明细。selected_score范围0-3，CASCADE级联删除')] }),
  new TableRow({ children: [TC('7'), TC('interventions\n（干预任务表）'), TC('intervention_id'), TC('（user_id, counselor_id, assess_id）'), TC('users(user_id)\ncounselors(counselor_id)\nassessments(assess_id)'), TC('干预任务。优先级：low/medium/high/urgent，状态：pending/in_progress/completed/cancelled')] }),
  new TableRow({ children: [TC('8'), TC('risk_levels\n（风险等级表）'), TC('risk_id'), TC('（user_id, last_assess_id）'), TC('users(user_id)\nassessments(assess_id)'), TC('每用户一条。风险等级：safe/watch/warning/crisis，ON UPDATE CURRENT_TIMESTAMP自动刷新')] }),
]}));
C.push(E());

C.push(H2('3.2 数据库关系图（4分）'));
C.push(P('（数据库ER关系图截图占位——请在MySQL Workbench或Navicat中导出mindcare数据库的EER Diagram并插入此处）'));
C.push(P('关系图应体现8张表之间的外键约束关系：'));
C.push(P('· users ↔ assessments：一对多（ON DELETE CASCADE）'));
C.push(P('· users ↔ risk_levels：一对一（UNIQUE约束，ON DELETE CASCADE）'));
C.push(P('· users ↔ interventions：一对多（ON DELETE CASCADE）'));
C.push(P('· scales ↔ questions：一对多（ON DELETE CASCADE）'));
C.push(P('· scales ↔ assessments：一对多'));
C.push(P('· assessments ↔ answers：一对多（ON DELETE CASCADE）'));
C.push(P('· assessments ↔ interventions：一对多（ON SET NULL）'));
C.push(P('· counselors ↔ interventions：一对多（ON SET NULL）'));
C.push(E());

C.push(BP('备注：'));
C.push(P('1. 数据表按先主表后从表的顺序创建（counselors → users → scales → questions → assessments → answers → risk_levels → interventions），保证外键约束有效。'));
C.push(P('2. 参照属性均为外键字段，严格关联被参照表主键。DELETE规则合理配置（CASCADE确保级联删除、SET NULL保护关联数据）。'));
C.push(P('3. 表间关系与ER图一致统一，满足数据完整性与业务逻辑。'));
C.push(P('4. 设计符合数据库规范化（3NF），无冗余数据，支撑系统全部功能。'));
C.push(PG());

// ===== 4. 事务删除操作 =====
C.push(H1('4. 含有事务应用的删除操作（13分）'));
C.push(H2('4.1 功能描述（1分）'));
C.push(P('管理员在用户管理页面注销用户时，通过数据库事务（BEGIN TRANSACTION → DELETE × N → COMMIT / ROLLBACK）原子级联删除该用户的所有关联数据，包括干预任务（interventions）、风险等级记录（risk_levels）、评估记录（assessments）、答题明细（answers，通过CASCADE自动删除）及用户主记录（users）。任意一步操作失败则全部回滚，保证数据一致性。'));
C.push(E());

C.push(H2('4.2 涉及的表（2分）'));
C.push(P('users、assessments、answers、interventions、risk_levels（共5张表）'));
C.push(E());

C.push(H2('4.3 表连接涉及字段（1分）'));
C.push(P('users.user_id = assessments.user_id'));
C.push(P('users.user_id = interventions.user_id'));
C.push(P('users.user_id = risk_levels.user_id'));
C.push(P('assessments.assess_id = answers.assess_id（通过CASCADE自动级联）'));
C.push(E());

C.push(H2('4.4 删除条件涉及的字段描述（1分）'));
C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('字段', 30), HC('规则', 70)] }),
  new TableRow({ children: [TC('users.user_id'), TC('等于指定的用户编号，用于唯一确定待删除用户')] }),
]}));
C.push(E());

C.push(H2('4.5 实现该操作的关键代码（4分）'));
C.push(BP('（1）后端Flask事务删除接口（app.py 第457-483行）：'));
C.push(...CODE([
  '@app.route("/api/admin/users/<int:uid>", methods=["DELETE"])',
  'def delete_user(uid):',
  '    db = get_db()',
  '    try:',
  '        db.begin()                    # 开启事务',
  '        with db.cursor() as cur:',
  '            cur.execute("SELECT * FROM users WHERE user_id=%s",(uid,))',
  '            user = cur.fetchone()',
  '            if not user:',
  '                db.rollback()         # 用户不存在，回滚',
  '                return error("用户不存在")',
  '',
  '            # 按外键依赖顺序逐表删除（先子表后主表）',
  '            cur.execute("DELETE FROM interventions WHERE user_id=%s",(uid,))',
  '            cur.execute("DELETE FROM risk_levels WHERE user_id=%s",(uid,))',
  '            # answers通过assessments的CASCADE自动删除',
  '            cur.execute("DELETE FROM assessments WHERE user_id=%s",(uid,))',
  '            cur.execute("DELETE FROM users WHERE user_id=%s",(uid,))',
  '            db.commit()               # 全部成功，提交事务',
  '',
  '        return success(msg=f"用户 {user[\"name\"]} 及所有关联数据已删除")',
  '    except Exception as e:',
  '        db.rollback()                 # 异常时回滚',
  '        return error(f"删除失败（事务回滚）: {str(e)}")'
]));
C.push(P('（后端事务删除代码截图占位——请插入app.py第457-483行截图）'));
C.push(E());

C.push(BP('（2）前端事务删除确认与进度展示（index.html 第1157-1203行）：'));
C.push(...CODE([
  'async function confirmDelete() {',
  '  const steps = ["users","assessments","answers","interventions","risk"];',
  '  // 模拟事务执行进度动画（逐表标记删除状态）',
  '  for(let i=0;i<steps.length;i++){',
  '    await new Promise(r=>setTimeout(r,300));',
  '    document.getElementById("icon-"+steps[i]).textContent="\u2713";',
  '    document.getElementById("icon-"+steps[i]).className="dp-icon success";',
  '    progressBar.style.width=((i+1)/steps.length*100)+"%";',
  '  }',
  '  // 实际调用后端事务删除API',
  '  const r=await api(`/admin/users/${currentDeleteUser.id}`,{method:"DELETE"});',
  '  if(r.code===0){ toast("事务删除成功！"); closeDeleteModal(); loadUsers(); }',
  '  else { toast(r.msg,"error"); }',
  '}'
]));
C.push(E());

C.push(H2('4.6 程序演示（4分）'));
C.push(BP('正常执行演示：'));
C.push(P('① 以管理员账号登录系统，进入"用户管理"页面'));
C.push(P('② 在用户列表中选择一位学生用户，点击"注销"按钮'));
C.push(P('③ 弹出确认对话框，展示将被级联删除的5类数据（users/assessments/answers/interventions/risk_levels）'));
C.push(P('④ 确认后，前端展示事务执行进度动画，依次标记各表删除状态'));
C.push(P('⑤ 后端执行db.begin() → 逐表DELETE → db.commit()，全部成功则返回成功消息'));
C.push(P('⑥ 用户列表自动刷新，被删除用户及所有关联数据从系统中移除'));
C.push(E());
C.push(BP('违背约束演示（回滚验证）：'));
C.push(P('① 在"数据库操作"演示页面的"事务删除"面板中，点击"测试回滚"按钮'));
C.push(P('② 后端尝试删除user_id=9999（不存在的用户）'));
C.push(P('③ 后端检测到用户不存在，执行db.rollback()回滚事务'));
C.push(P('④ 返回错误消息："用户不存在"，验证事务回滚机制正确工作'));
C.push(E());
C.push(P('备注：事务删除操作严格按外键依赖顺序执行（先删子表interventions/risk_levels/assessments，answers通过CASCADE自动删除，最后删主表users），保证不会违反外键约束。所有操作在try-except块中包裹，异常时自动回滚，确保数据一致性。'));
C.push(PG());

// ===== 5. 触发器操作 =====
C.push(H1('5. 触发器控制下的添加操作（20分）'));
C.push(H2('5.1 操作功能描述（1分）'));
C.push(P('学生提交心理测评后，后端向assessments表插入评估记录，数据库触发器trg_auto_intervention自动执行，根据评估等级自动生成干预任务、自动分配空闲咨询师、自动更新用户风险等级，实现评估→预警→干预全流程自动化，无需人工干预。'));
C.push(E());

C.push(H2('5.2 触发器功能描述（2分）'));
C.push(P('触发器名称：trg_auto_intervention'));
C.push(P('触发时机：AFTER INSERT ON assessments（行级触发，FOR EACH ROW）'));
C.push(P('触发器主要功能：'));
C.push(P('① 根据插入评估记录的level字段判断风险程度：severe→urgent优先级，moderate→high优先级'));
C.push(P('② 仅中度（moderate）及以上等级触发干预任务，自动生成包含分数和等级的触发原因描述'));
C.push(P('③ 自动选择空闲且接单最少的咨询师（SELECT counselor_id FROM counselors WHERE available=1 ORDER BY 当前任务数 ASC LIMIT 1）'));
C.push(P('④ 自动向interventions表插入干预任务记录（含user_id、counselor_id、trigger_reason、priority、status）'));
C.push(P('⑤ 自动更新risk_levels表：severe→crisis，moderate→warning，mild→watch，normal→safe（使用ON DUPLICATE KEY UPDATE支持覆盖更新）'));
C.push(E());

C.push(H2('5.3 涉及的表（1分）'));
C.push(P('assessments（主表，插入触发）、interventions（插入目标）、risk_levels（更新目标）、users（关联查询）、counselors（分配咨询师）——共5张表'));
C.push(E());

C.push(H2('5.4 输入数据及约束条件（2分）'));
C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('字段', 25), HC('约束规则', 75)] }),
  new TableRow({ children: [TC('assessments.user_id'), TC('非空，必须存在于users表中（外键约束）')] }),
  new TableRow({ children: [TC('assessments.scale_id'), TC('非空，必须存在于scales表中（外键约束）')] }),
  new TableRow({ children: [TC('assessments.total_score'), TC('整数且必须≥0（CHECK约束：chk_assess_score）')] }),
  new TableRow({ children: [TC('assessments.level'), TC('非空，ENUM枚举值：normal / mild / moderate / severe')] }),
]}));
C.push(E());

C.push(H2('5.5 实现该操作的关键代码（6分）'));
C.push(BP('（1）后端提交评估接口核心代码（app.py 第350-356行）：'));
C.push(...CODE([
  '# 插入评估记录（触发器trg_auto_intervention会自动执行）',
  'with db.cursor() as cur:',
  '    cur.execute(',
  '        "INSERT INTO assessments (user_id,scale_id,total_score,level)',
  '         VALUES (%s,%s,%s,%s)",',
  '        (uid, scale_id, total_score, level)',
  '    )',
  '    assess_id = cur.lastrowid',
  '    # 插入答题明细',
  '    for a in answers:',
  '        cur.execute(',
  '            "INSERT INTO answers (assess_id,question_id,selected_score)',
  '             VALUES (%s,%s,%s)",',
  '            (assess_id, a["question_id"], a["selected_score"])',
  '        )',
  '    db.commit()  # 触发器在COMMIT前已自动执行'
]));
C.push(P('（后端提交评估代码截图占位——请插入app.py第283-384行截图）'));
C.push(E());

C.push(BP('（2）触发器SQL源码（database/mindcare_init.sql 第145-218行）：'));
C.push(...CODE([
  'CREATE TRIGGER trg_auto_intervention',
  'AFTER INSERT ON assessments',
  'FOR EACH ROW',
  'BEGIN',
  '    DECLARE v_level VARCHAR(20);',
  '    DECLARE v_priority VARCHAR(20);',
  '    DECLARE v_reason VARCHAR(200);',
  '    DECLARE v_counselor_id INT;',
  '',
  '    SET v_level = NEW.level;',
  '',
  '    -- 根据等级设置优先级和触发原因',
  '    IF v_level = "severe" THEN',
  '        SET v_priority = "urgent";',
  '        SET v_reason = CONCAT("严重心理风险预警：评估得分 ",',
  '            NEW.total_score," 分，达到重度等级，需紧急干预");',
  '    ELSEIF v_level = "moderate" THEN',
  '        SET v_priority = "high";',
  '        SET v_reason = CONCAT("中度心理风险预警：评估得分 ",',
  '            NEW.total_score," 分，建议及时关注");',
  '    END IF;',
  '',
  '    -- 仅中度及以上才触发干预任务',
  "    IF v_level IN ('moderate', 'severe') THEN",
  '        -- 自动分配空闲咨询师（选择接单最少的）',
  '        SELECT counselor_id INTO v_counselor_id',
  '        FROM counselors WHERE available = 1',
  '        ORDER BY (SELECT COUNT(*) FROM interventions i',
  '            WHERE i.counselor_id = counselors.counselor_id',
  "            AND i.status IN ('pending','in_progress')) ASC",
  '        LIMIT 1;',
  '',
  '        -- 插入干预任务',
  '        INSERT INTO interventions (user_id,counselor_id,trigger_reason,',
  '            assess_id,priority,status)',
  '        VALUES (NEW.user_id,v_counselor_id,v_reason,NEW.assess_id,',
  "            v_priority,'pending');",
  '',
  '        -- 更新风险等级（ON DUPLICATE KEY UPDATE支持覆盖）',
  '        INSERT INTO risk_levels (user_id,risk_score,risk_level,last_assess_id)',
  '        VALUES (NEW.user_id,NEW.total_score,',
  "            CASE v_level WHEN 'severe' THEN 'crisis'",
  "                WHEN 'moderate' THEN 'warning' ELSE 'watch' END,",
  '            NEW.assess_id)',
  '        ON DUPLICATE KEY UPDATE',
  '            risk_score=NEW.total_score, risk_level=...,',
  '            last_assess_id=NEW.assess_id, updated_at=NOW();',
  '    END IF;',
  'END'
]));
C.push(P('（触发器SQL源码截图占位——请插入mindcare_init.sql第145-218行截图）'));
C.push(E());

C.push(H2('5.6 程序演示（8分）'));
C.push(BP('正常执行演示（4分）：'));
C.push(P('① 学生登录系统，进入"开始测评"页面，选择PHQ-9抑郁量表'));
C.push(P('② 逐题作答，选择中等偏高的分值（如18分），点击"提交测评"'));
C.push(P('③ 后端向assessments表插入记录（total_score=18, level="moderate"）'));
C.push(P('④ 数据库触发器trg_auto_intervention自动执行：判定为moderate→high优先级→自动分配咨询师→向interventions表插入干预任务→更新risk_levels表为warning等级'));
C.push(P('⑤ 前端展示测评结果页面，同时弹出"干预提醒"通知条'));
C.push(P('⑥ 管理员登录后在"干预任务管理"页面可看到自动生成的干预任务'));
C.push(P('说明：不违背触发器约束，评估插入成功，触发器自动完成干预任务生成和风险等级更新。'));
C.push(E());

C.push(BP('违背约束演示（4分）：'));
C.push(P('演示场景1——插入非法level值：点击"非法level值"按钮，后端尝试插入level="critical"的评估记录（不在ENUM范围内），MySQL返回错误："Data truncated for column \'level\'"，数据库约束生效，操作被拦截。'));
C.push(P('演示场景2——插入不存在的user_id：点击"不存在user_id"按钮，后端尝试插入user_id=9999的评估记录，MySQL返回错误："Cannot add or update a child row: a foreign key constraint fails"，外键约束生效。'));
C.push(P('演示场景3——插入负数分数：点击"负数分数"按钮，后端尝试插入total_score=-5的评估记录，MySQL返回错误："CHECK constraint \'chk_assess_score\' is violated"，CHECK约束生效。'));
C.push(P('演示场景4——答案分值越界：点击"答案分值越界"按钮，后端尝试在answers表插入selected_score=5（超出0-3范围），MySQL触发器trg_answers_before_insert返回错误："答题分值必须在0-3之间"，SIGNAL SQLSTATE 45000拦截。'));
C.push(P('说明：违背触发器/约束要求时，数据库正确拦截非法数据，操作被拒绝并返回错误信息。'));
C.push(E());
C.push(P('备注：本平台的风险预警全自动触发，所有风险判定逻辑均在数据库层通过触发器统一实现，无需后端额外编码，有效保障了数据的安全性与系统的健壮性。'));
C.push(PG());

// ===== 6. 存储过程操作 =====
C.push(H1('6. 存储过程控制下的更新操作（18分）'));
C.push(H2('6.1 操作功能描述（1分）'));
C.push(P('通过存储过程sp_calc_risk_score自动计算用户综合风险分数与风险等级，更新risk_levels表，实现评估结果→风险指数的自动化计算，支持重复调用与覆盖更新。'));
C.push(E());

C.push(H2('6.2 存储过程功能描述（1分）'));
C.push(P('存储过程名称：sp_calc_risk_score'));
C.push(P('输入参数：p_user_id（INT，用户ID）'));
C.push(P('输出参数：p_risk_level（VARCHAR(20)，最终风险等级）'));
C.push(P('具体计算逻辑：'));
C.push(P('① 取用户最近3次评估记录，按时间加权（最近权重3、次近权重2、最远权重1），使用ROW_NUMBER()窗口函数实现'));
C.push(P('② 加权平均分 = SUM(total_score × weight) / SUM(weight)'));
C.push(P('③ 综合风险分 = LEAST(100, 加权平均分 × 0.6 + 历史最高分 × 0.4)'));
C.push(P('④ 按分数映射等级：≥75→crisis（危机）、≥50→warning（警示）、≥25→watch（观察）、<25→safe（安全）'));
C.push(P('⑤ 自动写入/更新risk_levels表（使用INSERT ... ON DUPLICATE KEY UPDATE支持重复覆盖）'));
C.push(E());

C.push(H2('6.3 涉及的关系表（2分）'));
C.push(P('assessments（读取评估数据）、risk_levels（更新风险等级）——共2张表'));
C.push(E());

C.push(H2('6.4 表连接涉及字段（1分）'));
C.push(P('assessments.user_id = risk_levels.user_id'));
C.push(E());

C.push(H2('6.5 更改字段及修改规则（2分）'));
C.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: [
  new TableRow({ children: [HC('字段', 30), HC('修改规则', 70)] }),
  new TableRow({ children: [TC('risk_levels.risk_score'), TC('计算公式：LEAST(100, 加权平均分×0.6 + 历史最高分×0.4)。其中加权平均分取最近3次评估按时间权重（3:2:1）计算，历史最高分为该用户所有评估中的最高得分')] }),
  new TableRow({ children: [TC('risk_levels.risk_level'), TC('根据risk_score映射：≥75→crisis（危机）、≥50→warning（警示）、≥25→watch（观察）、<25→safe（安全）')] }),
]}));
C.push(E());

C.push(H2('6.6 实现该操作的关键代码（6分）'));
C.push(BP('（1）存储过程SQL源码（database/mindcare_init.sql 第225-284行）：'));
C.push(...CODE([
  'CREATE PROCEDURE sp_calc_risk_score(',
  '    IN p_user_id INT, OUT p_risk_level VARCHAR(20))',
  'BEGIN',
  '    DECLARE v_count INT DEFAULT 0;',
  '    DECLARE v_avg_score DECIMAL(8,2) DEFAULT 0;',
  '    DECLARE v_max_score DECIMAL(8,2) DEFAULT 0;',
  '    DECLARE v_risk_score DECIMAL(8,2) DEFAULT 0;',
  '    DECLARE v_risk_level VARCHAR(20) DEFAULT "safe";',
  '',
  '    -- 取最近3次评估的加权平均分（最近权重高）',
  '    SELECT COUNT(*),',
  '           SUM(total_score*weight)/SUM(weight),',
  '           MAX(total_score), MAX(assess_id)',
  '    INTO v_count,v_avg_score,v_max_score,v_last_id',
  '    FROM (',
  '        SELECT assess_id,total_score,',
  '               CASE ROW_NUMBER() OVER (ORDER BY assessed_at DESC)',
  '                   WHEN 1 THEN 3 WHEN 2 THEN 2 ELSE 1',
  '               END AS weight',
  '        FROM assessments WHERE user_id=p_user_id',
  '        ORDER BY assessed_at DESC LIMIT 3',
  '    ) AS recent;',
  '',
  '    -- 综合风险分 = 加权均值×0.6 + 历史最高分×0.4，上限100',
  '    SET v_risk_score=LEAST(100,(v_avg_score*0.6+v_max_score*0.4));',
  '',
  '    -- 判定风险等级',
  '    SET v_risk_level=CASE',
  '        WHEN v_risk_score>=75 THEN "crisis"',
  '        WHEN v_risk_score>=50 THEN "warning"',
  '        WHEN v_risk_score>=25 THEN "watch"',
  '        ELSE "safe" END;',
  '',
  '    -- 更新risk_levels表',
  '    INSERT INTO risk_levels (user_id,risk_score,risk_level,last_assess_id)',
  '    VALUES (p_user_id,v_risk_score,v_risk_level,v_last_id)',
  '    ON DUPLICATE KEY UPDATE',
  '        risk_score=v_risk_score,risk_level=v_risk_level,',
  '        last_assess_id=v_last_id,updated_at=NOW();',
  '    SET p_risk_level=v_risk_level;',
  'END'
]));
C.push(P('（存储过程SQL源码截图占位——请插入mindcare_init.sql第225-284行截图）'));
C.push(E());

C.push(BP('（2）后端调用存储过程代码（app.py 第366-371行）：'));
C.push(...CODE([
  '# 提交评估后调用存储过程重新计算综合风险',
  'with db.cursor() as cur:',
  '    cur.callproc("sp_calc_risk_score", [uid, ""])',
  '    cur.execute("SELECT @_sp_calc_risk_score_1")',
  '    result = cur.fetchone()',
  '    db.commit()'
]));
C.push(P('（后端调用存储过程截图占位——请插入app.py第366-371行截图）'));
C.push(E());

C.push(BP('（3）前端风险计算演示（index.html 第1388-1450行）：'));
C.push(...CODE([
  'async function startRiskCalc() {',
  '  const uid = document.getElementById("calc-user-select").value;',
  '  // 展示4步计算动画（读取→加权→计算→更新）',
  '  const steps = [',
  '    {id:1, text:"读取用户近3次测评记录..."},',
  '    {id:2, text:"应用时间权重（3:2:1）..."},',
  '    {id:3, text:"计算加权风险得分..."},',
  '    {id:4, text:"更新风险等级..."}];',
  '  for(let i=0;i<steps.length;i++){',
  '    updateStepAnimation(i);',
  '    await new Promise(r=>setTimeout(r,800));',
  '  }',
  '  // 调用后端API执行存储过程',
  '  const r=await api("/admin/calc-risk",',
  '    {method:"POST",body:{user_id:uid}});',
  '  // 展示计算结果',
  '}'
]));
C.push(E());

C.push(H2('6.7 程序演示（5分）'));
C.push(BP('正常执行演示（2分）：'));
C.push(P('① 管理员登录系统，进入"风险指数计算"页面'));
C.push(P('② 从下拉列表中选择一位有评估记录的学生用户'));
C.push(P('③ 点击"开始计算"按钮，前端展示4步计算动画'));
C.push(P('④ 后端调用sp_calc_risk_score存储过程：取最近3次评估→加权计算→判定等级→更新risk_levels'));
C.push(P('⑤ 展示计算结果：显示更新前后的风险分数和风险等级对比'));
C.push(P('说明：不违背存储过程约束，正常执行更新操作，risk_levels表被成功更新。'));
C.push(E());
C.push(BP('违背约束演示（2分）：'));
C.push(P('演示场景1——不存在用户：点击"不存在用户"按钮，调用sp_calc_risk_score_v2(9999)，存储过程参数校验检测到用户不存在，返回"ERROR:USER_NOT_FOUND"，事务回滚。'));
C.push(P('演示场景2——非法状态值：点击"非法状态值"按钮，调用sp_update_intervention(1, "deleted", ...)，存储过程检测到"deleted"不在合法状态列表中，返回"ERROR: 状态值非法"。'));
C.push(P('演示场景3——不存在干预任务：点击"不存在干预任务"按钮，调用sp_update_intervention(99999, "completed", ...)，存储过程检测到任务不存在，返回"ERROR: 干预任务不存在"。'));
C.push(P('说明：违背存储过程参数约束时，存储过程正确返回错误信息，不执行非法操作。'));
C.push(E());
C.push(P('备注：通过存储过程自动计算综合风险，评分规则科学（时间加权+历史最高分）、计算高效（数据库层聚合计算，ROW_NUMBER窗口函数），支持重复覆盖更新（ON DUPLICATE KEY UPDATE），体现了数据库智能化、模块化设计。同时还提供了sp_update_intervention存储过程用于更新干预任务状态并自动联动调整风险等级（完成干预后风险等级自动降级：crisis→warning→watch→safe）。'));
C.push(PG());

// ===== 7. 视图查询操作 =====
C.push(H1('7. 含有视图的查询操作（15分）'));
C.push(H2('7.1 操作功能描述（1分）'));
C.push(P('通过数据库视图进行多表联合查询，快速获取院系统计、干预详情、用户评估历史、每日报告、高风险用户明细等多维度数据，简化复杂查询，统一数据出口，提升数据展示效率与维护性。'));
C.push(E());

C.push(H2('7.2 视图功能描述（1分）'));
C.push(P('本项目共创建8个业务视图，覆盖统计报表、明细查询、趋势分析三大类型：'));
C.push(E());
C.push(BP('原有3个核心视图：'));
C.push(P('· v_dept_mental_stats（院系心理健康统计视图）：关联users + assessments表，LEFT JOIN按院系分组。统计各院系学生总数、测评次数、平均得分、各等级人数分布（normal/mild/moderate/severe）及中高风险率（risk_rate_pct）。用于数据总览页面和管理后台院系统计页面。'));
C.push(P('· v_intervention_detail（干预任务详情视图）：关联interventions + users + counselors + assessments表。展示干预任务完整信息：学生姓名/学号/院系、咨询师姓名/专长、触发原因/得分/等级、任务优先级/状态/时间。用于干预任务管理页面的列表展示。'));
C.push(P('· v_user_assess_history（用户评估历史视图）：关联assessments + users + scales + risk_levels表。展示用户所有评估记录：量表名称/类型、评估得分/等级/时间、当前风险等级。用于评估历史页面和个人档案页面。'));
C.push(E());
C.push(BP('新增5个拓展视图：'));
C.push(P('· v_daily_assess_report（每日评估汇总视图）：按日期聚合评估次数、用户数、各等级分布、干预触发数'));
C.push(P('· v_scale_usage_stats（量表使用统计视图）：各量表使用频次、用户数、平均分、高风险率'));
C.push(P('· v_counselor_workload（咨询师工作量视图）：各咨询师任务分布、完成率、紧急任务数'));
C.push(P('· v_high_risk_users（高风险用户明细视图）：warning和crisis等级用户的评估详情与干预统计'));
C.push(P('· v_monthly_trend（月度趋势统计视图）：按月份和院系统计评估趋势变化'));
C.push(E());

C.push(H2('7.3 涉及的关系表（2分）'));
C.push(P('users、assessments、scales、answers、interventions、risk_levels、counselors——共7张表'));
C.push(E());

C.push(H2('7.4 表连接涉及字段（1分）'));
C.push(P('users.user_id = assessments.user_id'));
C.push(P('assessments.scale_id = scales.scale_id'));
C.push(P('assessments.assess_id = interventions.assess_id'));
C.push(P('users.user_id = risk_levels.user_id'));
C.push(P('interventions.counselor_id = counselors.counselor_id'));
C.push(P('assessments.assess_id = answers.assess_id'));
C.push(E());

C.push(H2('7.5 实现该操作的关键代码（6分）'));
C.push(BP('（1）视图创建SQL代码（database/mindcare_init.sql）：'));
C.push(E());
C.push(P('① v_dept_mental_stats - 院系心理健康综合统计视图（第338-352行）：'));
C.push(...CODE([
  'CREATE OR REPLACE VIEW v_dept_mental_stats AS',
  'SELECT',
  '    u.department,',
  '    COUNT(DISTINCT u.user_id) AS total_students,',
  '    COUNT(DISTINCT a.assess_id) AS total_assessments,',
  '    ROUND(AVG(a.total_score), 2) AS avg_score,',
  '    SUM(CASE WHEN a.level="severe" THEN 1 ELSE 0 END) AS severe_count,',
  '    SUM(CASE WHEN a.level="moderate" THEN 1 ELSE 0 END) AS moderate_count,',
  '    SUM(CASE WHEN a.level="mild" THEN 1 ELSE 0 END) AS mild_count,',
  '    SUM(CASE WHEN a.level="normal" THEN 1 ELSE 0 END) AS normal_count,',
  '    ROUND(SUM(CASE WHEN a.level IN ("moderate","severe") THEN 1',
  '        ELSE 0 END)*100.0/NULLIF(COUNT(a.assess_id),0),2) AS risk_rate_pct',
  'FROM users u',
  'LEFT JOIN assessments a ON u.user_id = a.user_id',
  'GROUP BY u.department;'
]));
C.push(E());

C.push(P('② v_intervention_detail - 干预任务详情视图（第358-380行）：'));
C.push(...CODE([
  'CREATE OR REPLACE VIEW v_intervention_detail AS',
  'SELECT',
  '    i.intervention_id, u.student_id, u.name AS student_name,',
  '    u.department, u.grade,',
  '    c.name AS counselor_name, c.specialty AS counselor_specialty,',
  '    i.trigger_reason, i.priority, i.status,',
  '    a.total_score AS trigger_score, a.level AS trigger_level,',
  '    i.created_at, i.completed_at, i.notes',
  'FROM interventions i',
  'JOIN users u ON i.user_id = u.user_id',
  'LEFT JOIN counselors c ON i.counselor_id = c.counselor_id',
  'LEFT JOIN assessments a ON i.assess_id = a.assess_id;'
]));
C.push(E());

C.push(P('③ v_user_assess_history - 用户评估历史视图（第386-402行）：'));
C.push(...CODE([
  'CREATE OR REPLACE VIEW v_user_assess_history AS',
  'SELECT',
  '    u.user_id, u.student_id, u.name, u.department,',
  '    s.name AS scale_name, s.type AS scale_type,',
  '    a.assess_id, a.total_score, a.level, a.assessed_at,',
  '    rl.risk_level AS current_risk',
  'FROM assessments a',
  'JOIN users u ON a.user_id = u.user_id',
  'JOIN scales s ON a.scale_id = s.scale_id',
  'LEFT JOIN risk_levels rl ON u.user_id = rl.user_id;'
]));
C.push(P('（视图创建SQL截图占位——请插入mindcare_init.sql第335-402行截图）'));
C.push(E());

C.push(BP('（2）后端接口调用视图代码（app.py）：'));
C.push(E());
C.push(P('院系统计接口（app.py 第406-415行）——查询v_dept_mental_stats视图：'));
C.push(...CODE([
  '@app.route("/api/admin/dept-stats", methods=["GET"])',
  'def dept_stats():',
  '    with db.cursor() as cur:',
  '        cur.execute(',
  '            "SELECT * FROM v_dept_mental_stats',
  '             ORDER BY risk_rate_pct DESC")',
  '        return success(cur.fetchall())'
]));
C.push(E());

C.push(P('干预任务接口（app.py 第417-429行）——查询v_intervention_detail视图：'));
C.push(...CODE([
  '@app.route("/api/admin/interventions", methods=["GET"])',
  'def get_interventions():',
  '    status = request.args.get("status", "")',
  '    with db.cursor() as cur:',
  '        if status:',
  '            cur.execute(',
  '                "SELECT * FROM v_intervention_detail',
  '                 WHERE status=%s ORDER BY created_at DESC",',
  '                (status,))',
  '        else:',
  '            cur.execute(',
  '                "SELECT * FROM v_intervention_detail',
  '                 ORDER BY created_at DESC LIMIT 50")'
]));
C.push(E());

C.push(P('评估历史接口（app.py 第550-563行）——查询v_user_assess_history视图：'));
C.push(...CODE([
  '@app.route("/api/admin/view-history", methods=["GET"])',
  'def view_history():',
  '    dept = request.args.get("department", "")',
  '    with db.cursor() as cur:',
  '        if dept:',
  '            cur.execute(',
  '                "SELECT * FROM v_user_assess_history',
  '                 WHERE department=%s',
  '                 ORDER BY assessed_at DESC LIMIT 100",',
  '                (dept,))',
  '        else:',
  '            cur.execute(',
  '                "SELECT * FROM v_user_assess_history',
  '                 ORDER BY assessed_at DESC LIMIT 100")'
]));
C.push(P('（后端调用视图接口截图占位——请插入app.py第406-563行截图）'));
C.push(E());

C.push(H2('7.6 程序演示（4分）'));
C.push(P('① 管理员登录系统，进入"院系统计"页面，系统调用/api/admin/dept-stats接口查询v_dept_mental_stats视图，前端渲染柱状图、数据列表和详细分析三种视图'));
C.push(P('② 进入"干预任务管理"页面，系统调用/api/admin/interventions接口查询v_intervention_detail视图，展示所有干预任务含学生信息、咨询师信息、触发原因等，支持按状态筛选'));
C.push(P('③ 在"数据库操作"演示页面的"视图查询"面板中，可分别查询8个视图（院系统计、干预详情、评估历史、日报汇总、量表统计、咨询师工作量、高风险用户、月度趋势），每个视图展示查询结果表格及数据行数'));
C.push(E());
C.push(P('备注：'));
C.push(P('1. 视图实现多表联合封装，降低业务耦合，查询简洁高效。后端仅需一行SQL（SELECT * FROM view_name WHERE ...）即可获取多表关联数据。'));
C.push(P('2. 统一数据出口，保证统计口径一致。所有院系统计页面共用v_dept_mental_stats视图，确保数据一致性。'));
C.push(P('3. 数据关系清晰、易于维护。视图SQL集中管理，业务逻辑变更时只需修改视图定义，无需修改多处后端代码。'));
C.push(PG());

// ===== 附录 =====
C.push(H1('附录：项目文件结构与启动说明'));
C.push(H2('文件结构'));
C.push(...CODE([
  'MindCare/',
  '\u251c\u2500\u2500 app.py                          # Flask后端应用（935行）',
  '\u251c\u2500\u2500 index.html                      # 前端页面（1995行）',
  '\u251c\u2500\u2500 database/',
  '\u2502   \u251c\u2500\u2500 mindcare_init.sql           # 数据库初始化脚本',
  '\u2502   \u2514\u2500\u2500 mindcare_demo_data.sql      # 演示数据脚本',
  '\u251c\u2500\u2500 MindCare_\u6570\u636e\u5e93\u4f18\u5316\u65b9\u6848.sql       # 数据库优化方案（1641行）',
  '\u251c\u2500\u2500 SQL_code.sql                    # SQL代码汇总',
  '\u2514\u2500\u2500 \u5de5\u7a0b\u4f5c\u4e1a\u62a5\u544a.docx                # 本报告'
]));
C.push(E());

C.push(H2('启动步骤'));
C.push(P('1. 确保MySQL 8.0已安装并运行'));
C.push(P('2. pip install flask flask-cors pymysql'));
C.push(P('3. 执行database/mindcare_init.sql初始化数据库'));
C.push(P('4. 确认app.py中DB_CONFIG的密码配置与本地MySQL一致'));
C.push(P('5. python app.py启动后端服务'));
C.push(P('6. 浏览器访问 http://localhost:5000'));
C.push(P('7. 登录账号：管理员 admin / admin123，学生 2021001001 / 123456'));
C.push(E());

C.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { before: 400 },
  children: [new TextRun({ text: '\u2014\u2014 \u62a5\u544a\u5b8c \u2014\u2014', font: 'SimHei', size: 24, color: '888888' })]
}));

// ===== 生成文件 =====
const doc = new Document({ sections: [{ children: C }] });
const outPath = 'd:\\HuaweiMoveData\\Users\\asdf1\\Desktop\\数据库\\MindCare\\MindCare\\工程作业报告.docx';
Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync(outPath, buf);
  console.log('Done: ' + outPath);
}).catch(err => {
  console.error('Error:', err);
});
