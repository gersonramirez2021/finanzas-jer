import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { pool } from './config/db';
import authRoutes from './routes/auth.routes';
import ministeriosRoutes from './routes/ministerios.routes';
import usuariosRoutes from './routes/usuarios.routes';
import movimientosRoutes from './routes/movimientos.routes';
import categoriasRoutes from './routes/categorias.routes';
import misMinisteriosRoutes from './routes/mis-ministerios.routes';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/ministerios', ministeriosRoutes);
app.use('/api/usuarios', usuariosRoutes);
app.use('/api/movimientos', movimientosRoutes);
app.use('/api/categorias', categoriasRoutes);
app.use('/api/mis-ministerios', misMinisteriosRoutes);

app.get('/api/health', async (_req, res) => {
  try {
    const result = await pool.query('SELECT NOW() AS hora');
    res.json({ estado: 'ok', baseDeDatos: 'conectada', hora: result.rows[0].hora });
  } catch (error) {
    console.error(error);
    res.status(500).json({ estado: 'error', baseDeDatos: 'sin conexión' });
  }
});

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => {
  console.log(`Servidor corriendo en http://localhost:${port}`);
});