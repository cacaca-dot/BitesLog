const errorHandler = (err, req, res, next) => {
    console.error('Error:', err);

    // Error yang kita throw (dari service)
    if (err.statusCode) {
        return res.status(err.statusCode).json({
            status: 'error',
            error: { 
                code: err.code || 'ERROR', 
                message: err.message 
            }
        });
    }

    // Error tidak terduga (server error)
    return res.status(500).json({
        status: 'error',
        error: { 
            code: 'INTERNAL_SERVER_ERROR', 
            message: 'Terjadi kesalahan pada server' 
        }
    });
};

module.exports = errorHandler;