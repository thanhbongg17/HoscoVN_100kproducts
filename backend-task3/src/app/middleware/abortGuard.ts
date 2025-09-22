import type { RequestHandler } from 'express';

declare module 'express-serve-static-core' {
  interface Request {
    isAborted?: () => boolean;
  }
}

export const abortGuard: RequestHandler = (req, _res, next) => {
  let aborted = false;
  req.on('close', () => { aborted = true; });
  req.isAborted = () => aborted;
  next();
};
