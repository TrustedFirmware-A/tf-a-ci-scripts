-eval_file=toolchain.ecl

-eval_file=public_APIs.ecl
-public_files+=api:public

-eval_file=external_sources.ecl

-doc="Build version file is autogenerated and piped directly to compiler, captured by ECLAIR as /dev/pipe/XXX, changing from build to build, leading to spurious diffs."
#-file_tag+={external, "^_ROOT/dev/pipe/.*$"}
#-file_tag+={external, "^/dev/pipe/.*$"}
-source_files={hide, "^/dev/pipe/.*$"}

-doc="FIXME: cite the compiler manual section describing support for __asm__."
-config=MC3R1.R1.2,reports+={hide,"category(^STD.tokenext/__asm__$)"}

-doc="FIXME: cite the compiler manual section describing support for __attribute__."
-config=MC3R1.R1.2,reports+={hide,"category(^STD.tokenext/__attribute__$)"}

-doc="FIXME: cite the compiler manual section describing support for __typeof__."
-config=MC3R1.R1.2,reports+={hide,"category(^STD.tokenext/__typeof__$)"}

-doc_begin="Unless specified otherwise, a function with a non-const pointer argument is assumed not to read the pointee before writing it and it is assumed to write something to it before returning."
-default_call_properties+="pointee_read(1..=never)"
-default_call_properties+="pointee_write(1..=always)"
-doc_end


-doc="Unless specified otherwise, a function is assumed to not save/preserve the pointers received as arguments."
-default_call_properties+="taken()"

-remap_rtag={safe, hide}
# Hide known TODOs for now
-remap_rtag={todo, hide}
