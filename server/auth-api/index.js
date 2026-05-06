/**
 * Eunoia 账号 API：读写 data/users.json，密码 bcrypt 存储。
 * 默认端口 3848（与语聊 3847 错开）。
 */
const path = require('path');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 3848);
const DATA_FILE = process.env.AUTH_DATA_FILE
  ? path.resolve(process.env.AUTH_DATA_FILE)
  : path.join(__dirname, 'data', 'users.json');

const ACCOUNT_RE = /^[a-zA-Z0-9]{6,12}$/;
const REG_BONUS_E_POINTS = 1000;

function readDb() {
  const raw = fs.readFileSync(DATA_FILE, 'utf8');
  const parsed = JSON.parse(raw);
  if (!parsed.users || !Array.isArray(parsed.users)) {
    return { users: [] };
  }
  return parsed;
}

function writeDb(db) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(db, null, 2), 'utf8');
}

function publicUser(row) {
  const {
    password_hash: _p,
    ...rest
  } = row;
  return rest;
}

function randomEunoiaId() {
  return String(100000 + Math.floor(Math.random() * 900000));
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '32kb' }));

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'eunoia-auth-api' });
});

app.post('/register', (req, res) => {
  try {
    const account = String(req.body.account || '').trim();
    const password = String(req.body.password || '').trim();
    const displayNameRaw = req.body.displayName != null ? String(req.body.displayName).trim() : '';

    if (!account || !password) {
      res.status(400).json({ error: '账号或密码不能为空' });
      return;
    }
    if (!ACCOUNT_RE.test(account) || !ACCOUNT_RE.test(password)) {
      res.status(400).json({ error: '账号与密码须为 6～12 位英文字母或数字' });
      return;
    }

    const db = readDb();
    const exists = db.users.some((u) => u.account === account);
    if (exists) {
      res.status(400).json({ error: '账号已存在' });
      return;
    }

    const id = crypto.randomUUID();
    const display_name =
      displayNameRaw.length > 0 ? displayNameRaw : `烤鸭${Math.floor(Math.random() * 0xffffffff).toString(16).padStart(8, '0')}`;

    const row = {
      id,
      account,
      password_hash: bcrypt.hashSync(password, 10),
      display_name,
      bio: '',
      word_tower_max_floor: 0,
      check_in_total: 0,
      last_check_in_date: null,
      e_points: REG_BONUS_E_POINTS,
      blind_box_tickets: 0,
      check_in_streak: 0,
      eunoia_id: randomEunoiaId(),
    };
    db.users.push(row);
    writeDb(db);

    res.status(201).json({ user: publicUser(row) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.post('/login', (req, res) => {
  try {
    const account = String(req.body.account || '').trim();
    const password = String(req.body.password || '').trim();

    if (!account || !password) {
      res.status(400).json({ error: '账号或密码不能为空' });
      return;
    }

    const db = readDb();
    const row = db.users.find((u) => u.account === account);
    if (!row || !bcrypt.compareSync(password, row.password_hash)) {
      res.status(401).json({ error: '账号或密码错误' });
      return;
    }

    res.json({ user: publicUser(row) });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: '服务器错误' });
  }
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`eunoia-auth-api listening on http://127.0.0.1:${PORT}`);
  console.log(`data file: ${DATA_FILE}`);
});
