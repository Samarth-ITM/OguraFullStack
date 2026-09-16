#!/usr/bin/env python3
"""
Ogura Supabase / PostgREST Dev Transport Server
Connects to local PostgreSQL (ogura_dev) and exposes standard PostgREST and GoTrue Auth endpoints.
Used for local real-backend smoke testing and repository verification.
"""

import json
import sys
import re
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from decimal import Decimal
import datetime
import uuid
import psycopg2
import psycopg2.extras

DB_NAME = os.environ.get("PGDATABASE", "ogura_dev")
DB_USER = os.environ.get("PGUSER") or os.environ.get("USER") or "postgres"
DB_HOST = os.environ.get("PGHOST", "localhost")
DB_PORT = int(os.environ.get("PGPORT", 5432))
PORT = int(os.environ.get("PORT", 54321))

def json_serial(obj):
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    if isinstance(obj, uuid.UUID):
        return str(obj)
    raise TypeError(f"Type {type(obj)} not serializable")

def get_db_connection():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        host=DB_HOST,
        port=DB_PORT,
    )

class SupabaseDevHandler(BaseHTTPRequestHandler):
    def _send_cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "authorization, apikey, content-type, prefer")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors()
        self.end_headers()

    def _get_auth_user_id(self):
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:].strip()
            # Token can be raw UUID or a mock JWT containing sub or userId
            try:
                # Direct UUID test
                uuid.UUID(token)
                return token
            except ValueError:
                # If JWT format, try extracting sub
                parts = token.split(".")
                if len(parts) >= 2:
                    try:
                        import base64
                        padded = parts[1] + "=" * ((4 - len(parts[1]) % 4) % 4)
                        payload = json.loads(base64.b64decode(padded))
                        if "sub" in payload:
                            return payload["sub"]
                    except Exception:
                        pass
                if token and token != "anon" and not token.startswith("eyJ"):
                    return token
        return None

    def _read_json_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length > 0:
            raw = self.rfile.read(length)
            return json.loads(raw)
        return {}

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        body = self._read_json_body()
        user_id = self._get_auth_user_id()

        # Auth Endpoints
        if path == "/auth/v1/otp":
            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"{}")
            return

        if path == "/auth/v1/verify":
            email = body.get("email")
            phone = body.get("phone")
            conn = get_db_connection()
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            matched_user = None
            if email:
                cur.execute("SELECT id, email, phone FROM public.profiles WHERE email = %s LIMIT 1;", (email,))
                matched_user = cur.fetchone()
            elif phone:
                cur.execute("SELECT id, email, phone FROM public.profiles WHERE phone = %s LIMIT 1;", (phone,))
                matched_user = cur.fetchone()
            
            if not matched_user and email:
                # Fallback check on auth.users
                cur.execute("SELECT id, email, NULL as phone FROM auth.users WHERE email = %s LIMIT 1;", (email,))
                matched_user = cur.fetchone()

            conn.close()

            if matched_user:
                uid = str(matched_user["id"])
                resp = {
                    "access_token": uid,
                    "token_type": "bearer",
                    "expires_in": 3600,
                    "refresh_token": f"rt_{uid}",
                    "user": {
                        "id": uid,
                        "email": matched_user["email"] or "",
                        "phone": matched_user["phone"] or "",
                    }
                }
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(resp).encode("utf-8"))
            else:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"message": "Invalid credentials or user not found"}).encode("utf-8"))
            return

        if path == "/auth/v1/logout":
            self.send_response(200)
            self._send_cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b"{}")
            return

        # RPC Endpoints: /rest/v1/rpc/<func_name>
        if path.startswith("/rest/v1/rpc/"):
            func_name = path[len("/rest/v1/rpc/"):]
            conn = get_db_connection()
            try:
                cur = conn.cursor()
                # Set local auth claims
                if user_id:
                    cur.execute("SET LOCAL request.jwt.claim.sub = %s;", (user_id,))
                    cur.execute("SET LOCAL request.jwt.claims = %s;", (json.dumps({"sub": user_id, "role": "authenticated"}),))
                    cur.execute("SET LOCAL role = 'authenticated';")
                else:
                    cur.execute("SET LOCAL request.jwt.claim.sub = '';")
                    cur.execute("SET LOCAL role = 'anon';")

                # Inspect function parameter names
                cur.execute("""
                    SELECT parameter_name, data_type
                    FROM information_schema.parameters
                    WHERE specific_name LIKE %s AND parameter_mode = 'IN'
                    ORDER BY ordinal_position;
                """, (f"{func_name}_%",))
                param_rows = cur.fetchall()

                if not param_rows:
                    # Alternative lookup via pg_proc
                    cur.execute("""
                        SELECT p.proargnames
                        FROM pg_proc p
                        JOIN pg_namespace n ON p.pronamespace = n.oid
                        WHERE n.nspname = 'public' AND p.proname = %s
                        LIMIT 1;
                    """, (func_name,))
                    pro_row = cur.fetchone()
                    if pro_row and pro_row[0]:
                        param_rows = [(name, 'any') for name in pro_row[0]]

                arg_clauses = []
                arg_values = []
                if param_rows:
                    for name, _ in param_rows:
                        if name in body:
                            val = body[name]
                            if isinstance(val, (dict, list)):
                                arg_values.append(json.dumps(val))
                            else:
                                arg_values.append(val)
                            arg_clauses.append(f"{name} => %s")
                    
                    sql = f"SELECT to_jsonb(public.{func_name}({', '.join(arg_clauses)}));"
                else:
                    sql = f"SELECT to_jsonb(public.{func_name}());"

                cur.execute(sql, arg_values)
                res = cur.fetchone()
                conn.commit()

                data = res[0] if res else None
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(data, default=json_serial).encode("utf-8"))
            except Exception as e:
                conn.rollback()
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                err_msg = str(e).strip().splitlines()[0]
                self.wfile.write(json.dumps({"message": err_msg, "code": getattr(e, "pgcode", "P0001")}).encode("utf-8"))
            finally:
                conn.close()
            return

        # Table Insert: /rest/v1/<table>
        if path.startswith("/rest/v1/"):
            table_name = path[len("/rest/v1/"):]
            conn = get_db_connection()
            try:
                cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
                if user_id:
                    cur.execute("SET LOCAL request.jwt.claim.sub = %s;", (user_id,))
                    cur.execute("SET LOCAL request.jwt.claims = %s;", (json.dumps({"sub": user_id, "role": "authenticated"}),))
                    cur.execute("SET LOCAL role = 'authenticated';")
                else:
                    cur.execute("SET LOCAL request.jwt.claim.sub = '';")
                    cur.execute("SET LOCAL role = 'anon';")

                cols = list(body.keys())
                vals = [body[c] for c in cols]
                placeholders = ["%s"] * len(cols)
                sql = f"INSERT INTO public.{table_name} ({', '.join(cols)}) VALUES ({', '.join(placeholders)}) RETURNING *;"
                cur.execute(sql, vals)
                inserted = cur.fetchone()
                conn.commit()
                data = dict(inserted) if inserted else body
                self.send_response(201)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(data, default=json_serial).encode("utf-8"))
            except Exception as e:
                conn.rollback()
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"message": str(e), "code": getattr(e, "pgcode", "P0001")}).encode("utf-8"))
            finally:
                conn.close()
            return

        self.send_response(404)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        user_id = self._get_auth_user_id()

        if path.startswith("/rest/v1/"):
            table_name = path[len("/rest/v1/"):]
            conn = get_db_connection()
            try:
                cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
                if user_id:
                    cur.execute("SET LOCAL request.jwt.claim.sub = %s;", (user_id,))
                    cur.execute("SET LOCAL request.jwt.claims = %s;", (json.dumps({"sub": user_id, "role": "authenticated"}),))
                    cur.execute("SET LOCAL role = 'authenticated';")
                else:
                    cur.execute("SET LOCAL request.jwt.claim.sub = '';")
                    cur.execute("SET LOCAL role = 'anon';")

                where_clauses = []
                where_vals = []
                order_by = ""
                limit_val = None
                offset_val = None

                for k, v in qs.items():
                    val = v[0]
                    if k == "select":
                        continue
                    if k == "order":
                        parts = val.split(".")
                        order_by = f"ORDER BY {parts[0]} {'DESC' if len(parts) > 1 and parts[1].lower() == 'desc' else 'ASC'}"
                    elif k == "limit":
                        limit_val = int(val)
                    elif k == "offset":
                        offset_val = int(val)
                    elif val.startswith("eq."):
                        eq_val = val[3:]
                        where_clauses.append(f"{k} = %s")
                        where_vals.append(eq_val)
                    elif val.startswith("in.("):
                        in_vals = val[4:-1].split(",")
                        where_clauses.append(f"{k} = ANY(%s)")
                        where_vals.append(in_vals)

                where_str = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
                limit_str = f"LIMIT {limit_val}" if limit_val is not None else ""
                offset_str = f"OFFSET {offset_val}" if offset_val is not None else ""

                sql = f"SELECT * FROM public.{table_name} {where_str} {order_by} {limit_str} {offset_str};"
                cur.execute(sql, where_vals)
                rows = cur.fetchall()
                data = [dict(r) for r in rows]

                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(data, default=json_serial).encode("utf-8"))
            except Exception as e:
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"message": str(e), "code": getattr(e, "pgcode", "P0001")}).encode("utf-8"))
            finally:
                conn.close()
            return

        self.send_response(404)
        self.end_headers()

    def do_PATCH(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        body = self._read_json_body()
        user_id = self._get_auth_user_id()

        if path.startswith("/rest/v1/"):
            table_name = path[len("/rest/v1/"):]
            conn = get_db_connection()
            try:
                cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
                if user_id:
                    cur.execute("SET LOCAL request.jwt.claim.sub = %s;", (user_id,))
                    cur.execute("SET LOCAL request.jwt.claims = %s;", (json.dumps({"sub": user_id, "role": "authenticated"}),))
                    cur.execute("SET LOCAL role = 'authenticated';")
                else:
                    cur.execute("SET LOCAL request.jwt.claim.sub = '';")
                    cur.execute("SET LOCAL role = 'anon';")

                set_clauses = []
                vals = []
                for k, v in body.items():
                    set_clauses.append(f"{k} = %s")
                    vals.append(v)

                where_clauses = []
                for k, v in qs.items():
                    val = v[0]
                    if val.startswith("eq."):
                        where_clauses.append(f"{k} = %s")
                        vals.append(val[3:])

                where_str = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
                sql = f"UPDATE public.{table_name} SET {', '.join(set_clauses)} {where_str} RETURNING *;"
                cur.execute(sql, vals)
                updated = cur.fetchall()
                conn.commit()
                data = [dict(r) for r in updated]
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(data, default=json_serial).encode("utf-8"))
            except Exception as e:
                conn.rollback()
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"message": str(e), "code": getattr(e, "pgcode", "P0001")}).encode("utf-8"))
            finally:
                conn.close()
            return

        self.send_response(404)
        self.end_headers()

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        user_id = self._get_auth_user_id()

        if path.startswith("/rest/v1/"):
            table_name = path[len("/rest/v1/"):]
            conn = get_db_connection()
            try:
                cur = conn.cursor()
                if user_id:
                    cur.execute("SET LOCAL request.jwt.claim.sub = %s;", (user_id,))
                    cur.execute("SET LOCAL request.jwt.claims = %s;", (json.dumps({"sub": user_id, "role": "authenticated"}),))
                    cur.execute("SET LOCAL role = 'authenticated';")
                else:
                    cur.execute("SET LOCAL request.jwt.claim.sub = '';")
                    cur.execute("SET LOCAL role = 'anon';")

                where_clauses = []
                vals = []
                for k, v in qs.items():
                    val = v[0]
                    if val.startswith("eq."):
                        where_clauses.append(f"{k} = %s")
                        vals.append(val[3:])

                where_str = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""
                sql = f"DELETE FROM public.{table_name} {where_str};"
                cur.execute(sql, vals)
                conn.commit()
                self.send_response(200)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b"true")
            except Exception as e:
                conn.rollback()
                self.send_response(400)
                self._send_cors()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"message": str(e), "code": getattr(e, "pgcode", "P0001")}).encode("utf-8"))
            finally:
                conn.close()
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, format, *args):
        # Suppress noisy HTTP logs during testing
        return

if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", PORT), SupabaseDevHandler)
    print(f"OGURA Supabase dev bridge running on http://127.0.0.1:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
