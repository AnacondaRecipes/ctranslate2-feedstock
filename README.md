About ctranslate2
=================

Home: https://github.com/OpenNMT/CTranslate2

Package license: MIT

Feedstock license: [BSD-3-Clause](https://github.com/AnacondaRecipes/ctranslate2-feedstock/blob/main/LICENSE.txt)

Summary: Fast inference engine for Transformer models

Documentation: https://opennmt.net/CTranslate2

CTranslate2 is a C++ and Python library for efficient inference with Transformer models.
It implements a custom runtime that applies many performance optimization techniques such
as weights quantization, layer fusion, batch reordering, etc., to accelerate and reduce
the memory usage of Transformer models on CPU and GPU.

Packages
--------

| Name | Description |
| --- | --- |
| libctranslate2 | C++ shared library for Transformer model inference |
| ctranslate2 | Python bindings and model converter tools |

Installing ctranslate2
======================

```
conda install ctranslate2
```

Feedstock Maintainers
=====================

* [@xkong](https://github.com/xkong/)
