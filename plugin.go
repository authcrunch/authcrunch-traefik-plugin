package authcrunch_traefik_plugin

import (
	"context"
	"fmt"
	"net/http"
	"os"
)

type ZapShim struct{}

func (z *ZapShim) Info(msg string, fields ...interface{}) {
	fmt.Fprintf(os.Stdout, "INFO: %s %v\n", msg, fields)
}
func (z *ZapShim) Error(msg string, fields ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: %s %v\n", msg, fields)
}
func (z *ZapShim) Debug(msg string, fields ...interface{}) {
	fmt.Fprintf(os.Stdout, "DEBUG: %s %v\n", msg, fields)
}
func (z *ZapShim) Warn(msg string, fields ...interface{}) {
	fmt.Fprintf(os.Stdout, "WARN: %s %v\n", msg, fields)
}

// Config holds the plugin configuration.
type Config struct {
	// Server  *authcrunch.Config `json:"server,omitempty"`
	Mode           string `json:"mode,omitempty"` // "authenticate" or "authorize"
	Disabled       bool   `json:"disabled,omitempty"`
	isAuthenticate bool
}

// CreateConfig creates the default configuration.
func CreateConfig() *Config {
	return &Config{
		Disabled: false,
		// Server: authcrunch.NewConfig(),
		Mode: "unknown",
	}
}

// AuthCrunch is the middleware plugin structure.
type AuthCrunch struct {
	// server *authcrunch.Server
	// logger *zap.Logger
	logger *ZapShim
	next   http.Handler
	name   string
	config *Config
}

// New created a new AuthCrunch plugin instance.
func New(ctx context.Context, next http.Handler, config *Config, name string) (http.Handler, error) {
	if !config.Disabled {
		if config.Mode != "authenticate" && config.Mode != "authorize" {
			return nil, fmt.Errorf("authcrunch [%s] error: mode must be 'authenticate' or 'authorize', got %q", name, config.Mode)
		}
		if config.Mode == "authenticate" {
			config.isAuthenticate = true
		}
	}

	// if err := config.Server.Validate(); err != nil {
	// 	return nil, fmt.Errorf("failed to validate %q plugin config: %v", name, err)
	// }

	// encoderCfg := zap.NewProductionEncoderConfig()
	// core := zapcore.NewCore(
	// 	zapcore.NewConsoleEncoder(encoderCfg),
	// 	zapcore.AddSync(os.Stdout),
	// 	zap.DebugLevel,
	// )
	// logger := zap.New(core)

	// server, err := authcrunch.NewServer(config.Server, logger)
	// if err != nil {
	// 	return nil, fmt.Errorf("failed to initialize %q plugin server: %v", name, err)
	// }

	return &AuthCrunch{
		// server: server,
		// logger: logger,
		logger: &ZapShim{},
		next:   next,
		name:   name,
		config: config,
	}, nil
}

func (a *AuthCrunch) ServeHTTP(rw http.ResponseWriter, req *http.Request) {
	if a.config.Disabled {
		a.next.ServeHTTP(rw, req)
		return
	}

	a.logger.Info("processing request with AuthCrunch",
		"mode", a.config.Mode,
		"path", req.URL.Path,
	)

	if a.config.isAuthenticate {
		rw.Header().Set("Content-Type", "text/plain")
		rw.WriteHeader(http.StatusOK)
		fmt.Fprintln(rw, "AuthCrunch: Authenticated (Terminal)")
		return
	}

	req.Header.Set("X-Auth-Status", "Authorized")

	rw.Header().Set("X-Auth-Plugin", "AuthCrunch-Active")
	rw.Header().Set("X-Auth-Mode", "Authorize")

	a.next.ServeHTTP(rw, req)
}
