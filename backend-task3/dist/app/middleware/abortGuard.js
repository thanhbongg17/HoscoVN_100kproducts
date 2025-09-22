export const abortGuard = (req, _res, next) => {
    let aborted = false;
    req.on('close', () => { aborted = true; });
    req.isAborted = () => aborted;
    next();
};
