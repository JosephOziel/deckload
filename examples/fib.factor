H{
    {
        "+"
        V{
            T{ ir.rule
                { matcher
                    T{ matcher
                        { pat
                            V{
                                match-var
                                V{
                                    T{ match-const
                                        { const "z" }
                                    }
                                }
                            }
                        }
                        { eq-vars { } }
                    }
                }
                { body V{ T{ var { num 0 } } } }
            }
            T{ ir.rule
                { matcher
                    T{ matcher
                        { pat
                            V{
                                match-var
                                V{
                                    match-var
                                    T{ match-const
                                        { const "s" }
                                    }
                                }
                            }
                        }
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

USING: sequences.generalizations match ; 

FROM: syntax => _ ;

MATCH-VARS: 0 1 ;

! FIGURE OUT: when do group and when to not. its kinda confusing.
MACRO: `+` ( 0 0 -- 0 ) 
    2 narray 
    { { { 0 V{ T{ const { name "z" } } } } [ 0 '[ _ ] ] }
      { { 1 V{ 0 T{ const { name "s" } } } } [ 1 0 [ `+` ] T{ const { name "s" } } '[ _ _ _ call _ ] ] }
    } match-cond ;
