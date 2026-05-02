{ ... }: {
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
    environmentVariables = {
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE   = "q8_0";
    };
  };
}
