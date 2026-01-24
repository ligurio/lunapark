## CBMC proofs

### Usage

```
python -m venv venv_cbmc_viewer
source venv_cbmc_viewer/bin/activate
python3 -m pip install cbmc-viewer 3.11.1
sudo apt install universal-ctags

nix-shell -p cbmc
cmake -S . -B build -DUSE_LUA=ON -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=goto-cc -DENABLE_CBMC_PROOFS=ON -DENABLE_LUA_APICHECK=ON -DENABLE_LUA_ASSERT=ON
cmake --build build --target build_cbmc_proofs --parallel
ctest --test-dir build --output-on-failure --timeout 15 --tests-regex luaL_makeseed --verbose
cmake --build build -t luaL_makeseed-report --parallel
```
