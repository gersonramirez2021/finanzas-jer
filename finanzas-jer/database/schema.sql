\encoding UTF8

-- ROLES Y PERMISOS
CREATE TABLE roles (
  id_rol      SERIAL PRIMARY KEY,
  nombre      VARCHAR(50) NOT NULL UNIQUE,
  ambito      VARCHAR(15) NOT NULL CHECK (ambito IN ('sistema','ministerio')),
  descripcion TEXT
);

CREATE TABLE permisos (
  id_permiso  SERIAL PRIMARY KEY,
  codigo      VARCHAR(60) NOT NULL UNIQUE,
  descripcion TEXT
);

CREATE TABLE rol_permisos (
  id_rol     INT NOT NULL REFERENCES roles(id_rol) ON DELETE CASCADE,
  id_permiso INT NOT NULL REFERENCES permisos(id_permiso) ON DELETE CASCADE,
  PRIMARY KEY (id_rol, id_permiso)
);

-- USUARIOS Y MINISTERIOS
CREATE TABLE usuarios (
  id_usuario    SERIAL PRIMARY KEY,
  nombre        VARCHAR(80) NOT NULL,
  apellido      VARCHAR(80) NOT NULL,
  celular       VARCHAR(20),
  correo        VARCHAR(120) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  id_rol_sistema INT NOT NULL REFERENCES roles(id_rol),
  activo        BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ministerios (
  id_ministerio SERIAL PRIMARY KEY,
  nombre        VARCHAR(100) NOT NULL UNIQUE,
  descripcion   TEXT,
  es_privado    BOOLEAN NOT NULL DEFAULT FALSE,
  activo        BOOLEAN NOT NULL DEFAULT TRUE,
  creado_en     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE membresias (
  id_membresia  SERIAL PRIMARY KEY,
  id_usuario    INT NOT NULL REFERENCES usuarios(id_usuario),
  id_ministerio INT NOT NULL REFERENCES ministerios(id_ministerio),
  id_rol        INT NOT NULL REFERENCES roles(id_rol),
  activo        BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (id_usuario, id_ministerio)
);

-- FINANZAS
CREATE TABLE categorias (
  id_categoria  SERIAL PRIMARY KEY,
  nombre        VARCHAR(80) NOT NULL,
  tipo          VARCHAR(10) NOT NULL CHECK (tipo IN ('ingreso','egreso')),
  id_ministerio INT REFERENCES ministerios(id_ministerio),
  activa        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE movimientos (
  id_movimiento    SERIAL PRIMARY KEY,
  id_ministerio    INT NOT NULL REFERENCES ministerios(id_ministerio),
  id_categoria     INT NOT NULL REFERENCES categorias(id_categoria),
  tipo             VARCHAR(10) NOT NULL CHECK (tipo IN ('ingreso','egreso')),
  monto            NUMERIC(12,2) NOT NULL CHECK (monto > 0),
  descripcion      TEXT,
  fecha            DATE NOT NULL DEFAULT CURRENT_DATE,
  evidencia_url    TEXT,
  estado           VARCHAR(10) NOT NULL DEFAULT 'pendiente'
                   CHECK (estado IN ('pendiente','aprobado','rechazado','anulado')),
  id_registrado_por INT NOT NULL REFERENCES usuarios(id_usuario),
  id_aprobado_por   INT REFERENCES usuarios(id_usuario),
  fecha_aprobacion  TIMESTAMPTZ,
  creado_en        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE movimientos_his (
  id_historial   SERIAL PRIMARY KEY,
  id_movimiento  INT NOT NULL REFERENCES movimientos(id_movimiento),
  accion         VARCHAR(15) NOT NULL
                 CHECK (accion IN ('creado','editado','aprobado','rechazado','anulado')),
  id_usuario     INT NOT NULL REFERENCES usuarios(id_usuario),
  datos_anteriores JSONB,
  fecha_cambio   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mov_ministerio_fecha ON movimientos (id_ministerio, fecha);
CREATE INDEX idx_membresias_usuario ON membresias (id_usuario);

-- SALDO CALCULADO (solo movimientos aprobados)
CREATE VIEW saldo_ministerios AS
SELECT m.id_ministerio, m.nombre,
       COALESCE(SUM(CASE WHEN mv.tipo='ingreso' THEN mv.monto ELSE -mv.monto END), 0) AS saldo_actual
FROM ministerios m
LEFT JOIN movimientos mv
  ON mv.id_ministerio = m.id_ministerio AND mv.estado = 'aprobado'
GROUP BY m.id_ministerio, m.nombre;

-- DATOS INICIALES
INSERT INTO roles (nombre, ambito, descripcion) VALUES
 ('admin','sistema','Administra usuarios y ministerios; solo lectura de finanzas'),
 ('pastor','sistema','Lectura de todo y finanzas propias'),
 ('miembro','sistema','Usuario regular'),
 ('presidente','ministerio','Aprueba movimientos'),
 ('secretario','ministerio','Solo consulta'),
 ('tesorero','ministerio','Registra y edita movimientos'),
 ('integrante','ministerio','Miembro sin cargo');

INSERT INTO permisos (codigo, descripcion) VALUES
 ('usuarios.administrar','Crear y editar usuarios'),
 ('ministerios.administrar','Crear y editar ministerios'),
 ('finanzas.ver_todo','Ver finanzas de todos los ministerios publicos'),
 ('finanzas.ver_privado','Ver finanzas de ministerios privados'),
 ('movimientos.ver','Ver movimientos del ministerio propio'),
 ('movimientos.registrar','Registrar y editar movimientos'),
 ('movimientos.aprobar','Aprobar o rechazar movimientos');

INSERT INTO rol_permisos (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso FROM roles r JOIN permisos p ON
 (r.nombre='admin'      AND p.codigo IN ('usuarios.administrar','ministerios.administrar','finanzas.ver_todo'))
 OR (r.nombre='pastor'  AND p.codigo IN ('finanzas.ver_todo','finanzas.ver_privado'))
 OR (r.nombre='presidente' AND p.codigo IN ('movimientos.ver','movimientos.aprobar'))
 OR (r.nombre='secretario' AND p.codigo IN ('movimientos.ver'))
 OR (r.nombre='tesorero'   AND p.codigo IN ('movimientos.ver','movimientos.registrar'));

INSERT INTO ministerios (nombre, descripcion, es_privado) VALUES
 ('Pastoral','Finanzas del pastor (privado)', TRUE);