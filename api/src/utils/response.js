const success = (res, statusCode = 200, message = 'Success', data = null) => {
    const response = { status: 'success', message };
    if (data) response.data = data;
    return res.status(statusCode).json(response);
};

const error = (res, statusCode = 500, code = 'INTERNAL_ERROR', message = 'Something went wrong') => {
    return res.status(statusCode).json({
        status: 'error',
        error: { code, message }
    });
};

module.exports = { success, error };