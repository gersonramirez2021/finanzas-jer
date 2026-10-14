import { Pool, types } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

// Las columnas DATE se devuelven como texto 'AAAA-MM-DD', sin conversión de zona horaria
types.setTypeParser(1082, (valor: string) => valor);

export const pool = new Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});