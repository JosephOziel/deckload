H{
    {
        "+"
        V{
            T{ ir.rule
                { matcher
                    T{ matcher
                        { pat V{ match-var ~vector~ } }
                        { eq-vars { } }
                    }
                }
                { body V{ T{ var { num 0 } } } }
            }
            T{ ir.rule
                { matcher
                    T{ matcher
                        { pat V{ match-var ~vector~ } }
                        { eq-vars { } }
                    }
                }
                { body
                    V{
                        T{ var { num 1 } }
                        T{ var { num 0 } }
                        T{ const { name "+" } }
                        T{ const { name "s" } }
                    }
                }
            }
        }
    }
}