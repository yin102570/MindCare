# ============================================================
# MindCare 后端 Flask 应用
# ============================================================
from flask import Flask, request, jsonify, session, send_file
from flask_cors import CORS
import pymysql
import pymysql.cursors
from datetime import datetime, date, timedelta
import decimal
import json
import os
import hashlib
import secrets
import time

app = Flask(__name__)
app.secret_key = 'mindcare_secret_2026'
CORS(app)

# ============================================================
# Token 认证系统（替代 Cookie Session，解决跨域/文件协议问题）
# ============================================================
# 内存 token 存储: token -> {user_id, is_admin, expires_at}
_token_store = {}
TOKEN_EXPIRE_HOURS = 24

def generate_token(user_id, is_admin):
    """生成认证 token"""
    token = secrets.token_hex(32)
    _token_store[token] = {
        'user_id': user_id,
        'is_admin': is_admin,
        'expires_at': time.time() + TOKEN_EXPIRE_HOURS * 3600
    }
    return token

def get_current_user():
    """从请求头中获取当前用户ID（token 认证）"""
    # 方式1: Authorization header: Bearer <token>
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        token = auth[7:]
    else:
        # 方式2: X-Auth-Token header
        token = request.headers.get('X-Auth-Token', '')
        if not token:
            # 方式3: 兼容旧版 Cookie session
            uid = session.get('user_id')
            if uid:
                return uid, session.get('is_admin', False)
            return None, False

    entry = _token_store.get(token)
    if not entry:
        return None, False
    if time.time() > entry['expires_at']:
        del _token_store[token]
        return None, False
    return entry['user_id'], entry['is_admin']

def login_required(f):
    """装饰器：需要登录"""
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        uid, _ = get_current_user()
        if not uid:
            return error('未登录', 401)
        return f(*args, **kwargs)
    return decorated

def hash_password(password):
    """对密码进行SHA256哈希"""
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

# 前端页面路由
@app.route('/')
def index():
    frontend_path = os.path.join(os.path.dirname(__file__), 'index.html')
    return send_file(frontend_path)

# ============================================================
# 数据库连接配置
# ============================================================
DB_CONFIG = {
    'host':      'localhost',        # 数据库服务器地址
    'port':      3306,               # 端口
    'user':      'root',             # 用户名
    'password':  '123456',           # 密码
    'database':  'mindcare',         # 数据库名
    'charset':   'utf8mb4',          # 字符集
    'cursorclass': pymysql.cursors.DictCursor
}

def get_db():
    return pymysql.connect(**DB_CONFIG)

class JSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (datetime, date)):
            return obj.strftime('%Y-%m-%d %H:%M:%S') if isinstance(obj, datetime) else obj.strftime('%Y-%m-%d')
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super().default(obj)

app.json_encoder = JSONEncoder

def success(data=None, msg='success'):
    return jsonify({'code': 0, 'msg': msg, 'data': data})

def error(msg='error', code=1):
    return jsonify({'code': code, 'msg': msg, 'data': None})

# ============================================================
# 认证接口
# ============================================================
@app.route('/api/login', methods=['POST'])
def login():
    body = request.json
    db = get_db()
    try:
        with db.cursor() as cur:
            # 先按账号查询用户
            cur.execute(
                "SELECT * FROM users WHERE (student_id=%s OR email=%s)",
                (body.get('username'), body.get('username'))
            )
            user = cur.fetchone()
        if user:
            # 验证密码：支持明文和哈希两种方式（兼容旧数据）
            input_pwd = body.get('password', '')
            stored_pwd = user.get('password_hash', '')
            pwd_ok = (stored_pwd == input_pwd or stored_pwd == hash_password(input_pwd))
            if pwd_ok:
                is_admin = (user['department'] == '心理咨询中心')
                # 同时兼容 Cookie session 和 Token
                session['user_id'] = user['user_id']
                session['is_admin'] = is_admin
                session.modified = True
                token = generate_token(user['user_id'], is_admin)
                user.pop('password_hash', None)
                user['token'] = token
                return success(user)
        return error('用户名或密码错误', 401)
    finally:
        db.close()

@app.route('/api/logout', methods=['POST'])
def logout():
    # 清除 token
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        token = auth[7:]
        _token_store.pop(token, None)
    token = request.headers.get('X-Auth-Token', '')
    if token:
        _token_store.pop(token, None)
    session.clear()
    return success(msg='已退出')

@app.route('/api/me', methods=['GET'])
def me():
    uid, is_admin = get_current_user()
    if not uid:
        return error('未登录', 401)
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT user_id,student_id,name,gender,department,grade,phone,email,status,created_at FROM users WHERE user_id=%s", (uid,))
            user = cur.fetchone()
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (uid,))
            risk = cur.fetchone()
        return success({'user': user, 'risk': risk})
    finally:
        db.close()

# Session 检查接口（调试用）
@app.route('/api/session-check', methods=['GET'])
def session_check():
    """返回当前认证状态，用于调试登录态丢失问题"""
    uid, is_admin = get_current_user()
    auth = request.headers.get('Authorization', '')
    xtoken = request.headers.get('X-Auth-Token', '')
    return jsonify({
        'logged_in': uid is not None,
        'user_id': uid,
        'is_admin': is_admin,
        'auth_method': 'token' if (auth or xtoken) else ('cookie' if uid else 'none'),
        'has_auth_header': bool(auth),
        'has_xtoken_header': bool(xtoken),
        'has_cookie': 'session' in request.cookies
    })

# 我的档案
@app.route('/api/my/profile', methods=['GET'])
def my_profile():
    uid, _ = get_current_user()
    if not uid:
        return error('未登录', 401)
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT user_id,student_id,name,gender,department,grade,phone,email,status,created_at FROM users WHERE user_id=%s", (uid,))
            user = cur.fetchone()
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (uid,))
            risk = cur.fetchone()
            cur.execute("SELECT COUNT(*) as cnt FROM assessments WHERE user_id=%s", (uid,))
            count = cur.fetchone()['cnt']
        # 合并数据以匹配前端期望
        profile = {**user, **(risk or {}), 'assessment_count': count}
        return success(profile)
    finally:
        db.close()

# 我的评估历史
@app.route('/api/my/assessments', methods=['GET'])
def my_assessments():
    uid, _ = get_current_user()
    if not uid:
        return error('未登录', 401)
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                SELECT a.assess_id, a.total_score, a.level, a.assessed_at as assessment_date,
                       s.name as scale_name, s.type as scale_type,
                       rl.risk_level,
                       CASE WHEN i.intervention_id IS NOT NULL THEN 1 ELSE 0 END as intervention_triggered
                FROM assessments a
                JOIN scales s ON a.scale_id=s.scale_id
                LEFT JOIN interventions i ON a.assess_id=i.assess_id
                LEFT JOIN risk_levels rl ON a.user_id=rl.user_id
                WHERE a.user_id=%s ORDER BY a.assessed_at DESC LIMIT 50
            """, (uid,))
            assessments = cur.fetchall()
        return success(assessments)
    finally:
        db.close()

# ============================================================
# 量表 & 题目
# ============================================================
@app.route('/api/scales', methods=['GET'])
def get_scales():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT * FROM scales ORDER BY scale_id")
            scales = cur.fetchall()
            # 转换数据格式以匹配前端期望
            for s in scales:
                s['estimated_time'] = s.get('question_count', 5)  # 添加预估时间
            return success(scales)
    finally:
        db.close()

@app.route('/api/scales/<int:scale_id>/questions', methods=['GET'])
def get_questions(scale_id):
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT * FROM scales WHERE scale_id=%s", (scale_id,))
            scale = cur.fetchone()
            cur.execute("SELECT * FROM questions WHERE scale_id=%s ORDER BY seq_no", (scale_id,))
            questions = cur.fetchall()
            # 转换字段名以匹配前端期望
            for q in questions:
                q['question_text'] = q.pop('content')  # content -> question_text
                # 构建 options 数组
                options = []
                for i in range(4):
                    opt_key = f'opt_{i}'
                    if q.get(opt_key):
                        options.append({'text': q[opt_key], 'score': i})  # opt_0=0分, opt_1=1分, opt_2=2分, opt_3=3分
                q['options'] = options
            return success({'scale': scale, 'questions': questions})
    finally:
        db.close()

# ============================================================
# 提交评估（此部分为核心写入，触发器会自动触发）
# ============================================================
@app.route('/api/assessments', methods=['POST'])
def submit_assessment():
    uid, _ = get_current_user()
    if not uid:
        return error('未登录', 401)

    body = request.json
    scale_id = body.get('scale_id')
    answers  = body.get('answers', [])  # [{question_id, selected_score}, ...]

    # 计算总分
    total_score = sum(int(a.get('selected_score', 0)) for a in answers)

    # 根据量表类型判断等级
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT * FROM scales WHERE scale_id=%s", (scale_id,))
            scale = cur.fetchone()

        scale_type = scale.get('type', '')
        # PHQ-9: 0-4正常 5-9轻度 10-19中度 20-27重度
        # GAD-7: 0-4正常 5-9轻度 10-14中度 15-21重度
        # PSS-10: 0-12正常 13-26中等 27-40高压力
        # PSQI: 0-5正常 6-10睡眠障碍 11-15重度睡眠障碍
        if scale_type == 'depression':
            # PHQ-9 抑郁量表
            if total_score >= 20:
                level = 'severe'
            elif total_score >= 10:
                level = 'moderate'
            elif total_score >= 5:
                level = 'mild'
            else:
                level = 'normal'
        elif scale_type == 'anxiety':
            # GAD-7 焦虑量表
            if total_score >= 15:
                level = 'severe'
            elif total_score >= 10:
                level = 'moderate'
            elif total_score >= 5:
                level = 'mild'
            else:
                level = 'normal'
        elif scale_type == 'stress':
            # PSS-10 压力知觉量表
            if total_score >= 27:
                level = 'severe'
            elif total_score >= 13:
                level = 'moderate'
            elif total_score >= 0:
                level = 'mild'  # 0分以上就是有压力
            else:
                level = 'normal'
        else:
            # PSQI 睡眠质量：分数越高睡眠越差
            # 0-5正常 6-10睡眠障碍 11-21重度睡眠障碍
            if total_score >= 11:
                level = 'severe'
            elif total_score >= 6:
                level = 'moderate'
            elif total_score >= 0:
                level = 'mild'
            else:
                level = 'normal'

        with db.cursor() as cur:
            # 插入评估记录（触发器会自动执行）
            cur.execute(
                "INSERT INTO assessments (user_id,scale_id,total_score,level) VALUES (%s,%s,%s,%s)",
                (uid, scale_id, total_score, level)
            )
            assess_id = cur.lastrowid

            # 插入答题明细
            for a in answers:
                cur.execute(
                    "INSERT INTO answers (assess_id,question_id,selected_score) VALUES (%s,%s,%s)",
                    (assess_id, a['question_id'], a['selected_score'])
                )
            db.commit()

        # 调用存储过程重新计算综合风险
        with db.cursor() as cur:
            cur.callproc('sp_calc_risk_score', [uid, ''])
            cur.execute("SELECT @_sp_calc_risk_score_1")
            result = cur.fetchone()
            db.commit()

        with db.cursor() as cur:
            cur.execute("SELECT * FROM assessments WHERE assess_id=%s", (assess_id,))
            assess = cur.fetchone()
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (uid,))
            risk = cur.fetchone()

        return success({'assessment': assess, 'risk': risk, 'level': level, 'total_score': total_score})
    except Exception as e:
        db.rollback()
        return error(str(e))
    finally:
        db.close()

# ============================================================
# 查询接口
# ============================================================
@app.route('/api/assessments/history', methods=['GET'])
def assess_history():
    uid, _ = get_current_user()
    if not uid:
        return error('未登录', 401)
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                SELECT a.*, s.name as scale_name, s.type as scale_type
                FROM assessments a JOIN scales s ON a.scale_id=s.scale_id
                WHERE a.user_id=%s ORDER BY a.assessed_at DESC LIMIT 20
            """, (uid,))
            return success(cur.fetchall())
    finally:
        db.close()

@app.route('/api/admin/dept-stats', methods=['GET'])
def dept_stats():
    db = get_db()
    try:
        with db.cursor() as cur:
            # 使用视图查询
            cur.execute("SELECT * FROM v_dept_mental_stats ORDER BY risk_rate_pct DESC")
            return success(cur.fetchall())
    finally:
        db.close()

@app.route('/api/admin/interventions', methods=['GET'])
def get_interventions():
    status = request.args.get('status', '')
    db = get_db()
    try:
        with db.cursor() as cur:
            if status:
                cur.execute("SELECT * FROM v_intervention_detail WHERE status=%s ORDER BY created_at DESC", (status,))
            else:
                cur.execute("SELECT * FROM v_intervention_detail ORDER BY created_at DESC LIMIT 50")
            return success(cur.fetchall())
    finally:
        db.close()

@app.route('/api/admin/interventions/<int:iid>', methods=['PUT'])
def update_intervention(iid):
    body = request.json
    new_status = body.get('status', '')
    notes = body.get('notes', '')
    db = get_db()
    try:
        with db.cursor() as cur:
            # 调用存储过程
            cur.callproc('sp_update_intervention', [iid, new_status, notes, ''])
            cur.execute("SELECT @_sp_update_intervention_3")
            result = cur.fetchone()
            db.commit()
        result_str = list(result.values())[0] if result else ''
        if 'ERROR' in str(result_str):
            return error(result_str)
        return success(msg=str(result_str))
    except Exception as e:
        db.rollback()
        return error(str(e))
    finally:
        db.close()

# ============================================================
# 含事务的删除操作：管理员注销用户账号
# ============================================================
@app.route('/api/admin/users/<int:uid>', methods=['DELETE'])
def delete_user(uid):
    db = get_db()
    try:
        db.begin()
        with db.cursor() as cur:
            # 检查用户存在
            cur.execute("SELECT * FROM users WHERE user_id=%s", (uid,))
            user = cur.fetchone()
            if not user:
                db.rollback()
                return error('用户不存在')

            # 事务：按顺序删除（先删子表，再删主表）
            cur.execute("DELETE FROM interventions WHERE user_id=%s", (uid,))
            cur.execute("DELETE FROM risk_levels WHERE user_id=%s", (uid,))
            # answers 通过 assessments 的 CASCADE 自动删除
            cur.execute("DELETE FROM assessments WHERE user_id=%s", (uid,))
            cur.execute("DELETE FROM users WHERE user_id=%s", (uid,))
            db.commit()

        return success(msg=f'用户 {user["name"]} 及所有相关数据已删除')
    except Exception as e:
        db.rollback()
        return error(f'删除失败（事务回滚）: {str(e)}')
    finally:
        db.close()

@app.route('/api/admin/users', methods=['GET'])
def get_users():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("""
                SELECT u.user_id, u.student_id, u.name, u.gender, u.department, u.grade,
                       u.phone, u.status, u.created_at,
                       rl.risk_level, rl.risk_score
                FROM users u
                LEFT JOIN risk_levels rl ON u.user_id=rl.user_id
                WHERE u.department != '心理咨询中心'
                ORDER BY FIELD(rl.risk_level,'crisis','warning','watch','safe',NULL) ASC, u.created_at DESC
            """)
            return success(cur.fetchall())
    finally:
        db.close()

@app.route('/api/admin/dashboard', methods=['GET'])
def dashboard():
    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute("SELECT COUNT(*) as cnt FROM users WHERE department != '心理咨询中心'")
            total_users = cur.fetchone()['cnt']
            cur.execute("SELECT COUNT(*) as cnt FROM assessments")
            total_assessments = cur.fetchone()['cnt']
            cur.execute("SELECT COUNT(*) as cnt FROM interventions WHERE status='pending'")
            pending_interventions = cur.fetchone()['cnt']
            cur.execute("SELECT COUNT(*) as cnt FROM risk_levels WHERE risk_level IN ('warning','crisis')")
            high_risk_users = cur.fetchone()['cnt']
            # 最近7天评估趋势（补全缺失日期，确保曲线连续）
            cur.execute("""
                SELECT DATE(assessed_at) as day, COUNT(*) as cnt,
                       SUM(CASE WHEN level IN ('moderate','severe') THEN 1 ELSE 0 END) as risk_cnt
                FROM assessments
                WHERE assessed_at >= DATE_SUB(CURDATE(), INTERVAL 6 DAY)
                GROUP BY DATE(assessed_at) ORDER BY day
            """)
            db_trend = cur.fetchall()
            # 补全7天内缺失的日期（填充0）
            trend_map = {row['day'].strftime('%Y-%m-%d') if isinstance(row['day'], date) else str(row['day']): row for row in db_trend}
            trend = []
            for i in range(6, -1, -1):
                d = (datetime.now().date() - timedelta(days=i)).strftime('%Y-%m-%d')
                if d in trend_map:
                    trend.append({'day': d, 'cnt': trend_map[d]['cnt'], 'risk_cnt': trend_map[d]['risk_cnt']})
                else:
                    trend.append({'day': d, 'cnt': 0, 'risk_cnt': 0})
            # 等级分布
            cur.execute("""
                SELECT risk_level, COUNT(*) as cnt FROM risk_levels GROUP BY risk_level
            """)
            risk_dist = cur.fetchall()
        return success({
            'total_users': total_users,
            'total_assessments': total_assessments,
            'pending_interventions': pending_interventions,
            'high_risk_users': high_risk_users,
            'trend': trend,
            'risk_dist': risk_dist
        })
    finally:
        db.close()

@app.route('/api/admin/view-history', methods=['GET'])
def view_history():
    """通过视图查询全部评估历史"""
    dept = request.args.get('department', '')
    db = get_db()
    try:
        with db.cursor() as cur:
            if dept:
                cur.execute("SELECT * FROM v_user_assess_history WHERE department=%s ORDER BY assessed_at DESC LIMIT 100", (dept,))
            else:
                cur.execute("SELECT * FROM v_user_assess_history ORDER BY assessed_at DESC LIMIT 100")
            return success(cur.fetchall())
    finally:
        db.close()

# ============================================================
# 存储过程：风险计算
# ============================================================
@app.route('/api/admin/calc-risk', methods=['POST'])
def calc_risk():
    """调用存储过程计算用户风险指数"""
    body = request.json
    user_id = body.get('user_id')

    if not user_id:
        return error('请选择用户')

    # 确保 user_id 是整数，防止 SQL 注入
    try:
        user_id = int(user_id)
    except (ValueError, TypeError):
        return error('无效的用户ID')

    db = get_db()
    try:
        with db.cursor() as cur:
            # 使用参数化调用存储过程
            cur.execute("SET @p_risk_level = ''")
            cur.execute("CALL sp_calc_risk_score(%s, @p_risk_level)", (user_id,))
            cur.execute("SELECT @p_risk_level as risk_level_out")
            result = cur.fetchone()
            db.commit()

            # 获取更新后的风险等级
            cur.execute("""
                SELECT risk_score, risk_level FROM risk_levels
                WHERE user_id=%s
            """, (user_id,))
            risk = cur.fetchone()

            # 获取评估数量
            cur.execute("""
                SELECT COUNT(*) as cnt FROM assessments
                WHERE user_id=%s
            """, (user_id,))
            count = cur.fetchone()['cnt']

        return success({
            'risk_score': float(risk['risk_score']) if risk and risk['risk_score'] else 0,
            'risk_level': risk['risk_level'] if risk else 'safe',
            'assessment_count': count
        })
    except Exception as e:
        db.rollback()
        return error(str(e))
    finally:
        db.close()

# ============================================================
# 工程作业演示接口：数据库操作验证
# ============================================================

@app.route('/api/demo/trigger-test', methods=['POST'])
def demo_trigger_test():
    """演示触发器操作：提交评估 → 触发器自动干预"""
    uid, _ = get_current_user()
    if not uid:
        return error('未登录', 401)

    body = request.json
    scale_id = body.get('scale_id', 1)
    total_score = body.get('total_score', 15)
    level = body.get('level', 'moderate')
    note = body.get('note', '工程作业演示：触发器自动干预测试')

    db = get_db()
    try:
        with db.cursor() as cur:
            cur.execute(
                "INSERT INTO assessments (user_id, scale_id, total_score, level, note) VALUES (%s,%s,%s,%s,%s)",
                (uid, scale_id, total_score, level, note)
            )
            assess_id = cur.lastrowid
            db.commit()

        # 查看触发器自动生成的干预任务
        with db.cursor() as cur:
            cur.execute(
                "SELECT * FROM interventions WHERE assess_id=%s",
                (assess_id,)
            )
            intervention = cur.fetchone()
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (uid,))
            risk = cur.fetchone()

        return success({
            'assessment_id': assess_id,
            'intervention': intervention,
            'risk_levels': risk,
            'message': '触发器已自动执行：生成干预任务 + 更新风险等级'
        })
    except Exception as e:
        db.rollback()
        return error(f'触发器操作失败: {str(e)}')
    finally:
        db.close()


@app.route('/api/demo/trigger-violation', methods=['POST'])
def demo_trigger_violation():
    """演示约束/触发器校验：输入值通过则写入数据库，不通过则被拦截"""
    body = request.json
    test_type = body.get('test_type', '')

    db = get_db()
    try:
        if test_type == 'invalid_level':
            custom_level = body.get('custom_level', 'critical')
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO assessments (user_id, scale_id, total_score, level) VALUES (%s,%s,%s,%s)",
                    (1, 1, 10, custom_level)
                )
                assess_id = cur.lastrowid
                db.commit()
            # 写入成功 → 回查实际数据及触发器副作用
            with db.cursor() as cur:
                cur.execute("SELECT * FROM assessments WHERE assess_id=%s", (assess_id,))
                inserted = cur.fetchone()
                cur.execute("SELECT * FROM interventions WHERE assess_id=%s", (assess_id,))
                intervention = cur.fetchone()
                cur.execute("SELECT * FROM risk_levels WHERE user_id=1")
                risk = cur.fetchone()
            return success({
                'status': 'passed',
                'assess_id': assess_id,
                'inserted': inserted,
                'intervention_triggered': intervention,
                'risk_updated': risk,
                'message': f'level="{custom_level}" 通过了 CHECK 约束，数据已写入 assessments 表！打开 Navicat 按 Ctrl+R 即可看到。'
            })

        elif test_type == 'invalid_user':
            custom_user_id = int(body.get('custom_user_id', 9999))
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO assessments (user_id, scale_id, total_score, level) VALUES (%s,%s,%s,%s)",
                    (custom_user_id, 1, 10, 'moderate')
                )
                assess_id = cur.lastrowid
                db.commit()
            with db.cursor() as cur:
                cur.execute("SELECT * FROM assessments WHERE assess_id=%s", (assess_id,))
                inserted = cur.fetchone()
                cur.execute("SELECT u.name FROM users WHERE user_id=%s", (custom_user_id,))
                user_row = cur.fetchone()
                cur.execute("SELECT * FROM interventions WHERE assess_id=%s", (assess_id,))
                intervention = cur.fetchone()
                cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (custom_user_id,))
                risk = cur.fetchone()
            user_name = list(user_row.values())[0] if user_row else f'ID={custom_user_id}'
            return success({
                'status': 'passed',
                'assess_id': assess_id,
                'inserted': inserted,
                'intervention_triggered': intervention,
                'risk_updated': risk,
                'message': f'user_id={custom_user_id}（{user_name}）存在，外键约束通过，数据已写入！Navicat 按 Ctrl+R 可见。'
            })

        elif test_type == 'negative_score':
            custom_score = int(body.get('custom_score', -5))
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO assessments (user_id, scale_id, total_score, level) VALUES (%s,%s,%s,%s)",
                    (1, 1, custom_score, 'normal')
                )
                assess_id = cur.lastrowid
                db.commit()
            with db.cursor() as cur:
                cur.execute("SELECT * FROM assessments WHERE assess_id=%s", (assess_id,))
                inserted = cur.fetchone()
                cur.execute("SELECT * FROM interventions WHERE assess_id=%s", (assess_id,))
                intervention = cur.fetchone()
                cur.execute("SELECT * FROM risk_levels WHERE user_id=1")
                risk = cur.fetchone()
            return success({
                'status': 'passed',
                'assess_id': assess_id,
                'inserted': inserted,
                'intervention_triggered': intervention,
                'risk_updated': risk,
                'message': f'分数={custom_score} 通过了 CHECK 约束，数据已写入！Navicat 按 Ctrl+R 可见。'
            })

        elif test_type == 'invalid_answer_score':
            custom_answer_score = int(body.get('custom_answer_score', 5))
            with db.cursor() as cur:
                cur.execute(
                    "INSERT INTO answers (assess_id, question_id, selected_score) VALUES (%s,%s,%s)",
                    (1, 1, custom_answer_score)
                )
                db.commit()
            with db.cursor() as cur:
                cur.execute("SELECT * FROM answers WHERE assess_id=1 ORDER BY answer_id DESC LIMIT 1")
                inserted = cur.fetchone()
            return success({
                'status': 'passed',
                'inserted': inserted,
                'message': f'答案分值={custom_answer_score} 通过了约束校验，数据已写入 answers 表！Navicat 按 Ctrl+R 可见。'
            })

        else:
            return error('请选择测试类型')

    except Exception as e:
        db.rollback()
        return error(f'数据库约束/触发器生效，操作被拒绝: {str(e)}')
    finally:
        db.close()


@app.route('/api/demo/procedure-test', methods=['POST'])
def demo_procedure_test():
    """演示存储过程操作：调用sp_calc_risk_score计算风险"""
    body = request.json
    user_id = body.get('user_id')

    if not user_id:
        return error('请提供用户ID')

    # 确保 user_id 是整数，防止 SQL 注入
    try:
        user_id = int(user_id)
    except (ValueError, TypeError):
        return error('无效的用户ID')

    db = get_db()
    try:
        # 先查看计算前的状态
        with db.cursor() as cur:
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (user_id,))
            before = cur.fetchone()
            cur.execute(
                "SELECT assess_id, total_score, level, assessed_at FROM assessments WHERE user_id=%s ORDER BY assessed_at DESC LIMIT 5",
                (user_id,)
            )
            recent_assess = cur.fetchall()

        # 调用存储过程
        with db.cursor() as cur:
            cur.execute("SET @p_risk_level = ''")
            cur.execute("CALL sp_calc_risk_score(%s, @p_risk_level)", (user_id,))
            cur.execute("SELECT @p_risk_level as risk_level_out")
            result = cur.fetchone()
            db.commit()

        # 查看计算后的状态
        with db.cursor() as cur:
            cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (user_id,))
            after = cur.fetchone()

        return success({
            'before': before,
            'after': after,
            'recent_assessments': recent_assess,
            'procedure_result': list(result.values())[0] if result else '',
            'calculation': '加权平均分×0.6 + 历史最高分×0.4 → 映射 safe/watch/warning/crisis'
        })
    except Exception as e:
        db.rollback()
        return error(f'存储过程执行失败: {str(e)}')
    finally:
        db.close()


@app.route('/api/demo/procedure-violation', methods=['POST'])
def demo_procedure_violation():
    """演示存储过程参数校验：输入值通过则执行成功，不通过则返回错误"""
    body = request.json
    test_type = body.get('test_type', '')

    db = get_db()
    try:
        if test_type == 'user_not_found':
            custom_user_id = int(body.get('custom_user_id', 9999))
            with db.cursor() as cur:
                cur.execute("SET @p_result = ''")
                cur.execute("CALL sp_calc_risk_score_v2(%s, @p_result)", (custom_user_id,))
                cur.execute("SELECT @p_result as result_out")
                result = cur.fetchone()
                db.commit()
            result_str = list(result.values())[0] if result else ''
            if 'ERROR' in str(result_str).upper():
                return error(f'存储过程参数校验生效: {result_str}')
            # 用户存在 → 回查 risk_levels 变化
            with db.cursor() as cur:
                cur.execute("SELECT * FROM risk_levels WHERE user_id=%s", (custom_user_id,))
                risk = cur.fetchone()
                cur.execute("SELECT name FROM users WHERE user_id=%s", (custom_user_id,))
                user_row = cur.fetchone()
            user_name = list(user_row.values())[0] if user_row else f'ID={custom_user_id}'
            return success({
                'status': 'passed',
                'risk_levels': risk,
                'procedure_result': result_str,
                'message': f'user_id={custom_user_id}（{user_name}）存在，存储过程执行成功！风险等级已更新。Navicat 按 Ctrl+R 查看 risk_levels 表。'
            })

        elif test_type == 'invalid_status':
            custom_status = body.get('custom_status', 'deleted')
            with db.cursor() as cur:
                cur.execute("SET @p_result = ''")
                cur.execute("CALL sp_update_intervention(1, %s, '测试自定状态', @p_result)", (custom_status,))
                cur.execute("SELECT @p_result as result_out")
                result = cur.fetchone()
                db.commit()
            result_str = list(result.values())[0] if result else ''
            if 'ERROR' in str(result_str).upper():
                return error(f'存储过程参数校验生效: {result_str}')
            # 状态合法 → 回查干预任务变化
            with db.cursor() as cur:
                cur.execute("SELECT * FROM interventions WHERE intervention_id=1")
                intervention = cur.fetchone()
            return success({
                'status': 'passed',
                'intervention': intervention,
                'procedure_result': result_str,
                'message': f'status="{custom_status}" 合法，存储过程执行成功！干预任务 #1 已更新。Navicat 按 Ctrl+R 查看 interventions 表。'
            })

        elif test_type == 'intervention_not_found':
            custom_intervention_id = int(body.get('custom_intervention_id', 99999))
            with db.cursor() as cur:
                cur.execute("SET @p_result = ''")
                cur.execute("CALL sp_update_intervention(%s, 'completed', '测试自定ID', @p_result)", (custom_intervention_id,))
                cur.execute("SELECT @p_result as result_out")
                result = cur.fetchone()
                db.commit()
            result_str = list(result.values())[0] if result else ''
            if 'ERROR' in str(result_str).upper():
                return error(f'存储过程参数校验生效: {result_str}')
            # 干预任务存在 → 回查变化
            with db.cursor() as cur:
                cur.execute("SELECT * FROM interventions WHERE intervention_id=%s", (custom_intervention_id,))
                intervention = cur.fetchone()
            return success({
                'status': 'passed',
                'intervention': intervention,
                'procedure_result': result_str,
                'message': f'干预任务 #{custom_intervention_id} 存在，存储过程执行成功！状态已更新为 completed。Navicat 按 Ctrl+R 查看。'
            })

        else:
            return error('请选择测试类型')

    except Exception as e:
        db.rollback()
        return error(f'数据库异常: {str(e)}')
    finally:
        db.close()


@app.route('/api/demo/view-query', methods=['GET'])
def demo_view_query():
    """演示视图查询：封装多表JOIN的复杂查询"""
    view_name = request.args.get('view', 'v_dept_mental_stats')
    limit = request.args.get('limit', 20)

    db = get_db()
    try:
        # 限制可查询的视图白名单
        allowed_views = [
            'v_dept_mental_stats', 'v_intervention_detail',
            'v_user_assess_history', 'v_daily_assess_report',
            'v_scale_usage_stats', 'v_counselor_workload',
            'v_high_risk_users', 'v_monthly_trend'
        ]
        if view_name not in allowed_views:
            return error('视图不存在或无权访问')

        with db.cursor() as cur:
            # 使用白名单验证视图名，limit 参数化为整数
            cur.execute(f"SELECT * FROM {view_name} LIMIT %s", (int(limit),))
            data = cur.fetchall()

        # 获取视图涉及的表信息
        view_info = {
            'v_dept_mental_stats': '涉及 users + assessments，按院系统计心理健康数据',
            'v_intervention_detail': '涉及 interventions + users + counselors + assessments，干预任务详情',
            'v_user_assess_history': '涉及 assessments + users + scales + risk_levels，用户评估历史',
            'v_daily_assess_report': '涉及 assessments + interventions，每日评估汇总',
            'v_scale_usage_stats': '涉及 scales + assessments，量表使用统计',
            'v_counselor_workload': '涉及 counselors + interventions，咨询师工作量',
            'v_high_risk_users': '涉及 users + risk_levels + assessments + scales，高风险用户明细',
            'v_monthly_trend': '涉及 assessments + users，月度趋势统计'
        }

        return success({
            'view_name': view_name,
            'description': view_info.get(view_name, ''),
            'row_count': len(data),
            'data': data,
            'note': '视图封装了多表JOIN，简化查询、统一数据出口'
        })
    except Exception as e:
        return error(f'视图查询失败: {str(e)}')
    finally:
        db.close()


@app.route('/api/demo/delete-verify', methods=['GET'])
def demo_delete_verify():
    """演示事务删除前验证：查看级联删除将影响的数据"""
    user_id = request.args.get('user_id')

    if not user_id:
        return error('请提供用户ID')

    db = get_db()
    try:
        with db.cursor() as cur:
            # 用户信息
            cur.execute("SELECT user_id, student_id, name, department, grade FROM users WHERE user_id=%s", (user_id,))
            user = cur.fetchone()
            if not user:
                return error('用户不存在')

            # 各表关联数据统计
            cur.execute("SELECT COUNT(*) as cnt FROM interventions WHERE user_id=%s", (user_id,))
            inter_count = cur.fetchone()['cnt']

            cur.execute("SELECT COUNT(*) as cnt FROM risk_levels WHERE user_id=%s", (user_id,))
            risk_count = cur.fetchone()['cnt']

            cur.execute("SELECT COUNT(*) as cnt FROM assessments WHERE user_id=%s", (user_id,))
            assess_count = cur.fetchone()['cnt']

            # answers 通过 CASCADE 删除
            cur.execute("""
                SELECT COUNT(*) as cnt FROM answers
                WHERE assess_id IN (SELECT assess_id FROM assessments WHERE user_id=%s)
            """, (user_id,))
            answer_count = cur.fetchone()['cnt']

        return success({
            'user': user,
            'cascade_data': {
                'interventions': inter_count,
                'risk_levels': risk_count,
                'assessments': assess_count,
                'answers': answer_count,
                'users': 1
            },
            'note': '事务删除将原子性删除以上所有数据，任意一步失败则全部回滚'
        })
    finally:
        db.close()


# ============================================================
# 演示专用：恢复被删除的演示用户（事务回滚的反向演示）
# ============================================================
@app.route('/api/demo/restore-users', methods=['POST'])
def restore_demo_users():
    """重新插入被意外删除的演示用户，以事务保证原子性"""
    db = get_db()
    demo_users = [
        ('2021001001', '张明', '男', '计算机科学与技术学院', '2021级', '13900001001', 'zhangming@mail.edu'),
        ('2021001002', '李华', '女', '计算机科学与技术学院', '2021级', '13900001002', 'lihua@mail.edu'),
        ('2022002001', '王芳', '女', '心理学院', '2022级', '13900002001', 'wangfang@mail.edu'),
        ('2022002002', '赵磊', '男', '心理学院', '2022级', '13900002002', 'zhaolei@mail.edu'),
        ('2021003001', '陈伟', '男', '经济管理学院', '2021级', '13900003001', 'chenwei@mail.edu'),
        ('2023004001', '刘洋', '男', '物理学院', '2023级', '13900004001', 'liuyang@mail.edu'),
        ('2023004002', '孙静', '女', '物理学院', '2023级', '13900004002', 'sunjing@mail.edu'),
        ('admin', '管理员', '男', '心理咨询中心', '管理', '13900000001', 'admin@mindcare.edu'),
    ]
    restored = []
    try:
        db.begin()
        with db.cursor() as cur:
            for (sid, name, gender, dept, grade, phone, email) in demo_users:
                # 检查是否已存在
                cur.execute("SELECT user_id FROM users WHERE student_id = %s", (sid,))
                if cur.fetchone():
                    continue
                pwd = 'admin123' if sid == 'admin' else '123456'
                cur.execute(
                    "INSERT INTO users (student_id, name, gender, department, grade, phone, email, password_hash) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, SHA2(%s, 256))",
                    (sid, name, gender, dept, grade, phone, email, pwd)
                )
                restored.append(f'{sid}({name})')
            db.commit()
        if restored:
            return success(msg=f'已恢复 {len(restored)} 个演示用户：{", ".join(restored)}')
        else:
            return success(msg='所有演示用户均已存在，无需恢复')
    except Exception as e:
        db.rollback()
        return error(f'恢复失败（事务回滚）: {str(e)}')
    finally:
        db.close()


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
