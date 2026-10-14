\encoding UTF8

CREATE TABLE membresias_his (
  id_historial   SERIAL PRIMARY KEY,
  id_usuario     INT NOT NULL REFERENCES usuarios(id_usuario),
  id_ministerio  INT NOT NULL REFERENCES ministerios(id_ministerio),
  accion         VARCHAR(10) NOT NULL
                 CHECK (accion IN ('asignado','cambiado','revocado')),
  cargo_anterior VARCHAR(50),
  cargo_nuevo    VARCHAR(50),
  id_hecho_por   INT NOT NULL REFERENCES usuarios(id_usuario),
  fecha          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_membresias_his_usuario ON membresias_his (id_usuario, id_ministerio);