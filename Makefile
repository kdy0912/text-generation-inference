install-server:
	cd server && make install

install-custom-kernels:
	if [ "$$BUILD_EXTENSIONS" = "True" ]; then cd server/custom_kernels && python setup.py install; else echo "Custom kernels are disabled, you need to set the BUILD_EXTENSIONS environment variable to 'True' in order to build them. (Please read the docs, kernels might not work on all hardware)"; fi

install-integration-tests:
	cd integration-tests && pip install -r requirements.txt
	cd clients/python && pip install .

install-router:
	cd router && cargo install --path .

install-launcher:
	cd launcher && cargo install --path .

install-benchmark:
	cd benchmark && cargo install --path .

install: install-server install-router install-launcher install-custom-kernels

install-vllm:
	pip install -U packaging ninja  --no-cache-dir
	cd server/vllm && python setup.py build
	pip uninstall vllm -y || true
	cd server/vllm && python setup.py install

install-flash-attn:
	cd server && git clone https://github.com/HazyResearch/flash-attention.git
	cd server/flash-attention && git fetch && git checkout 3a9bfd076f98746c73362328958dbc68d145fbec
	cd server/flash-attention && python setup.py build
	cd server/flash-attention/csrc/rotary && python setup.py build
	cd server/flash-attention/csrc/layer_norm && python setup.py build
	pip uninstall flash_attn rotary_emb dropout_layer_norm -y || true
	cd server/flash-attention && python setup.py install && cd csrc/layer_norm && python setup.py install && cd ../rotary && python setup.py install

install-flash-attn-v2:
	cd server && git clone https://github.com/HazyResearch/flash-attention.git flash-attention-v2
	cd server/flash-attention-v2 && git fetch && git checkout 02ac572f3ffc4f402e4183aaa6824b45859d3ed3
	cd server/flash-attention-v2 && git submodule update --init --recursive
	cd server/flash-attention-v2 && python setup.py build
	cd server/flash-attention-v2 && git submodule update --init --recursive && python setup.py install

install-exllamav2_kernels:
	cd server/exllamav2_kernels && python setup.py install

all:
	pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 --index-url https://download.pytorch.org/whl/cu121
	BUILD_EXTENSIONS=True make install
	MAX_JOBS=4 make install-vllm
	MAX_JOBS=4 make install-flash-attn
	MAX_JOBS=4 make install-flash-attn-v2
	make install-exllamav2_kernels

server-dev:
	cd server && make run-dev

router-dev:
	cd router && cargo run -- --port 8080

rust-tests: install-router install-launcher
	cargo test

integration-tests: install-integration-tests
	pytest -s -vv -m "not private" integration-tests

update-integration-tests: install-integration-tests
	pytest -s -vv --snapshot-update integration-tests

python-server-tests:
	HF_HUB_ENABLE_HF_TRANSFER=1 pytest -s -vv -m "not private" server/tests

python-client-tests:
	pytest clients/python/tests

python-tests: python-server-tests python-client-tests

run-falcon-7b-instruct:
	text-generation-launcher --model-id tiiuae/falcon-7b-instruct --port 8080

run-falcon-7b-instruct-quantize:
	text-generation-launcher --model-id tiiuae/falcon-7b-instruct --quantize bitsandbytes --port 8080

clean:
	rm -rf target aml
