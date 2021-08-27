local bit = require("bit")
local ffi = require("ffi")

ffi.cdef[[
int memcmp(const void *s1, const void *s2, size_t n);

typedef struct bio_st BIO;
typedef struct bio_method_st BIO_METHOD;
BIO_METHOD *BIO_s_mem(void);
BIO * BIO_new(BIO_METHOD *type);
int BIO_puts(BIO *bp, const char *buf);
void BIO_vfree(BIO *a);

typedef struct rsa_st RSA;
RSA *RSA_new(void);
void RSA_free(RSA *rsa);
typedef int pem_password_cb(char *buf, int size, int rwflag, void *userdata);
RSA * PEM_read_bio_RSAPrivateKey(BIO *bp, RSA **rsa, pem_password_cb *cb,
                                 void *u);
RSA * PEM_read_bio_RSAPublicKey(BIO *bp, RSA **rsa, pem_password_cb *cb,
                                void *u);
RSA * PEM_read_bio_RSA_PUBKEY(BIO *bp, RSA **rsa, pem_password_cb *cb,
                                void *u);

unsigned long ERR_get_error_line_data(const char **file, int *line,
                                      const char **data, int *flags);
const char * ERR_reason_error_string(unsigned long e);

typedef struct bignum_st BIGNUM;
BIGNUM *BN_new(void);
void BN_free(BIGNUM *a);
typedef unsigned long BN_ULONG;
int BN_set_word(BIGNUM *a, BN_ULONG w);
typedef struct bn_gencb_st BN_GENCB;
int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);

typedef struct evp_cipher_st EVP_CIPHER;
int PEM_write_bio_RSAPrivateKey(BIO *bp, RSA *x, const EVP_CIPHER *enc,
                                unsigned char *kstr, int klen,
                                pem_password_cb *cb, void *u);
int PEM_write_bio_RSAPublicKey(BIO *bp, RSA *x);
int PEM_write_bio_RSA_PUBKEY(BIO *bp, RSA *x);

long BIO_ctrl(BIO *bp, int cmd, long larg, void *parg);
int BIO_read(BIO *b, void *data, int len);

typedef struct evp_pkey_st EVP_PKEY;
typedef struct engine_st ENGINE;
typedef struct evp_pkey_ctx_st EVP_PKEY_CTX;

EVP_PKEY *EVP_PKEY_new(void);
void EVP_PKEY_free(EVP_PKEY *key);

EVP_PKEY_CTX *EVP_PKEY_CTX_new(EVP_PKEY *pkey, ENGINE *e);
void EVP_PKEY_CTX_free(EVP_PKEY_CTX *ctx);

int EVP_PKEY_CTX_ctrl(EVP_PKEY_CTX *ctx, int keytype, int optype,
                      int cmd, int p1, void *p2);

int EVP_PKEY_size(EVP_PKEY *pkey);

int EVP_PKEY_encrypt_init(EVP_PKEY_CTX *ctx);
int EVP_PKEY_encrypt(EVP_PKEY_CTX *ctx,
        unsigned char *out, size_t *outlen,
        const unsigned char *in, size_t inlen);

int EVP_PKEY_decrypt_init(EVP_PKEY_CTX *ctx);
int EVP_PKEY_decrypt(EVP_PKEY_CTX *ctx,
                     unsigned char *out, size_t *outlen,
                     const unsigned char *in, size_t inlen);

int EVP_PKEY_set1_RSA(EVP_PKEY *pkey, RSA *key);
int PEM_write_bio_PKCS8PrivateKey(BIO *bp, EVP_PKEY *x, const EVP_CIPHER *enc,
                                  char *kstr, int klen, pem_password_cb *cb,
                                  void *u);

void OpenSSL_add_all_digests(void);
typedef struct env_md_st EVP_MD;
typedef struct env_md_ctx_st EVP_MD_CTX;
const EVP_MD *EVP_get_digestbyname(const char *name);

/* EVP_MD_CTX methods for OpenSSL < 1.1.0 */
EVP_MD_CTX *EVP_MD_CTX_create(void);
void EVP_MD_CTX_destroy(EVP_MD_CTX *ctx);

/* EVP_MD_CTX methods for OpenSSL >= 1.1.0 */
EVP_MD_CTX *EVP_MD_CTX_new(void);
void EVP_MD_CTX_free(EVP_MD_CTX *ctx);

int EVP_DigestInit(EVP_MD_CTX *ctx, const EVP_MD *type);
int EVP_DigestUpdate(EVP_MD_CTX *ctx, const unsigned char *in, int inl);
int EVP_SignFinal(EVP_MD_CTX *ctx,unsigned char *sig,unsigned int *s,
                  EVP_PKEY *pkey);
int EVP_VerifyFinal(EVP_MD_CTX *ctx,unsigned char *sigbuf, unsigned int siglen,
                    EVP_PKEY *pkey);
int EVP_PKEY_set1_RSA(EVP_PKEY *e, RSA *r);

void ERR_set_error_data(char *data, int flags);
]]

local ERR_TXT_STRING = 0x02

local evp_md_ctx_new
local evp_md_ctx_free
if not pcall(function () return ffi.C.EVP_MD_CTX_create end) then
    evp_md_ctx_new = ffi.C.EVP_MD_CTX_new
    evp_md_ctx_free = ffi.C.EVP_MD_CTX_free
else
    evp_md_ctx_new = ffi.C.EVP_MD_CTX_create
    evp_md_ctx_free = ffi.C.EVP_MD_CTX_destroy
end

local function ssl_err()
    local err_queue = {}
    local i = 1
    local data = ffi.new("const char*[1]")
    local flags = ffi.new("int[1]")

    while true do
        local code = ffi.C.ERR_get_error_line_data(nil, nil, data, flags)
        if code == 0 then
            break
        end

        local err = ffi.C.ERR_reason_error_string(code)
        err_queue[i] = ffi.string(err)
        i = i + 1

        if data[0] ~= nil and bit.band(flags[0], ERR_TXT_STRING) > 0 then
            err_queue[i] = ffi.string(data[0])
            i = i + 1
        end
    end

    return nil, table.concat(err_queue, ": ", 1, i - 1)
end

local function sign(self, str)
    if ffi.C.EVP_DigestUpdate(self.md_ctx, str, #str) <= 0 then
        return ssl_err()
    end

    local buf = self.buf
    local len = ffi.new("unsigned int[1]")
    if ffi.C.EVP_SignFinal(self.md_ctx, self.buf, len, self.pkey) <= 0 then
        return ssl_err()
    end

    return ffi.string(buf, len[0])
end


local function verify(self, str, sig)
    if ffi.C.EVP_DigestUpdate(self.md_ctx, str, #str) <= 0 then
        return ssl_err()
    end

    local siglen = #sig
    local buf = siglen <= self.size and self.buf
        or ffi.new("unsigned char[?]", siglen)
    ffi.copy(buf, sig, siglen)
    if ffi.C.EVP_VerifyFinal(self.md_ctx, buf, siglen, self.pkey) <= 0 then
        return ssl_err()
    end

    return true
end

local function new(opts)
    local key, read_func, md

    if opts.public_key then
        key = opts.public_key
        read_func = ffi.C.PEM_read_bio_RSA_PUBKEY
    elseif opts.private_key then
        key = opts.private_key
        read_func = ffi.C.PEM_read_bio_RSAPrivateKey
    else
        return nil, "public_key or private_key not found"
    end

    local bio_method = ffi.C.BIO_s_mem()
    local bio = ffi.C.BIO_new(bio_method)
    ffi.gc(bio, ffi.C.BIO_vfree)
    local len = ffi.C.BIO_puts(bio, key)
    if len < 0 then
        return ssl_err()
    end

    local rsa = read_func(bio, nil, nil, nil)
    if rsa == nil then
        return ssl_err()
    end

    ffi.gc(rsa, ffi.C.RSA_free)
    local pkey = ffi.C.EVP_PKEY_new()
    ffi.gc(pkey, ffi.C.EVP_PKEY_free)
    if ffi.C.EVP_PKEY_set1_RSA(pkey, rsa) == 0 then
        return ssl_err()
    end

    md = ffi.C.EVP_get_digestbyname('RSA-SHA256')

    local size = ffi.C.EVP_PKEY_size(pkey)

    local md_ctx = evp_md_ctx_new()
    if md_ctx == nil then
        return ssl_err()
    end
    ffi.gc(md_ctx, evp_md_ctx_free)

    if ffi.C.EVP_DigestInit(md_ctx, md) <= 0 then
        return ssl_err()
    end

    local self = {
        pkey = pkey,
        size = size,
        md_ctx = md_ctx,
        buf = ffi.new("unsigned char[?]", size),
        md = md,
    }

    return setmetatable(self, {
        __index = {
            sign = sign,
            verify = verify
        }
    })
end

return {
    new = new
}
