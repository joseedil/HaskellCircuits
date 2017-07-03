module TypeSynth where

import Control.Monad (forM_,forM)
import TransformationMonad
import Types
import Lexer
import Aux

noLocLow = L NoLoc . Low
noLocUpp = L NoLoc . Upp
noLocDec = L NoLoc . Dec
noLocBin = L NoLoc . Bin

typeSynth :: TMM ()
typeSynth = do
  defineListFunctions
  definePatternFunctions
  debug "--------------------------------------------------"
  dds <- getDataDecls
  debugs dds
  debug "--------------------------------------------------"
  changeTypes
  ret ()

defineListFunctions :: TM ()
defineListFunctions = do
  TCore fs <- getTCore
  let tys = gatherListTypes fs
  debugs tys
  substListByList_
  forM tys $ \ty -> do
    let nt = getNameFromType ty
    addData (noLoc ("List_" ++ nt)
            ,[CConstr (noLocUpp ("Nil_" ++ nt)) []
             ,CConstr (noLocUpp ("Cons_" ++ nt))
               [ty, CTAExpr (noLocUpp ("List_" ++ nt))]]
            ,True
            ,False)
  ok
  where
    noLoc = L NoLoc

substListByList_ :: TM ()
substListByList_ = do
  TCore fs <- getTCore
  fs' <- forM fs $ \(TCFunc name vars fgs ty) -> do
    let vars' = substVars vars
        fgs' = substGs fgs
        ty' = substTy ty
    return $ TCFunc name vars' fgs' ty'
  putTCore $ TCore fs'
 where substVars = map (\(a,t) -> (a,substTy t))
       getNameTy t = case t of
         CTApp (L s (Upp "List")) [CTAExpr (L _ (Upp nt))] -> nt
         CTApp (L s (Upp "List")) [CTApp (L _ (Upp nt)) _] -> nt
         x -> error $ "getnamety " ++ show x
       substTy t = case t of
         CTApp (L s (Upp "List")) [CTAExpr (L _ (Upp nt))]
           -> CTAExpr (L s (Upp ("List_" ++ nt)))
         CTApp (L s (Upp "List")) [CTApp (L _ (Upp nt)) _]
           -> CTAExpr (L s (Upp ("List_" ++ nt)))
         CTApp ltk as -> CTApp ltk (map substTy as)
         x -> x
       substGs gs = case gs of
         TCNoGuards e -> TCNoGuards $ substExpr e
         TCGuards ces ->
           TCGuards $ for ces (\(c,e) -> (substExpr c, substExpr e))
       substExpr expr = case expr of
         TCApp (L s (Upp "Cons")) as ty
           -> TCApp
              (L s (Upp ("Cons_" ++ getNameTy ty)))
              (map substExpr as)
              (substTy ty)
         TCAExpr (L s (Upp "Nil"), ty)
           -> TCAExpr
              (L s (Upp ("Nil_" ++ getNameTy ty))
              ,substTy ty)
         TCApp ltk as ty -> TCApp ltk (map substExpr as) (substTy ty)
         x -> x
         

gatherListTypes :: [TCFunc] -> [CFType]
gatherListTypes = concat . map gatherTys
  where gatherTys (TCFunc _ varsNtys _ ty)
          = gatherIf ty ++ concat (map (gatherIf . snd) varsNtys)
        gatherIf cft = case cft of
          CTApp (L _ (Upp "List")) [ty] -> [ty]
          _ -> []
               
definePatternFunctions :: TMM ()
definePatternFunctions = do
  dds <- getDataDecls
  forM_ dds $ \(L _ name,_,_,_) -> do
    definePatternFunctions' name
  ret ()
  
definePatternFunctions' :: Name -> TMM ()
definePatternFunctions' "Int"   = mok
definePatternFunctions' "Fixed" = mok
definePatternFunctions' name = do
  mdd <- searchDataDecl name
  cont1 mdd $ \dd@(_,_,isRec,_) -> case isRec of
    True  -> definePatternFunctionsRec dd
    False -> definePatternFunctionsNonRec dd

arrangeConstrs :: [CConstr] -> [CConstr]
arrangeConstrs cs = case nils of
  []  -> error "infinite dd"
  [x] -> x : notnils
  _   -> error "multiple endings"
  where nils = filter isNil cs
        notnils = filter (not . isNil) cs
        isNil (CConstr _ []) = True
        isNil (CConstr _  _) = False

definePatternFunctionsRec :: (L Name, [CConstr], IsRec, Used)
                             -> TMM ()
definePatternFunctionsRec (L s name, constrs', _, used) = do
  case used of
    True -> mok
    False -> do
      let constrs = arrangeConstrs constrs'
          p = length constrs
          n = ceiling (logBase 2 (fromIntegral p))
          tags = map (toBin n) [0..(p-1)]
          constrsNtags = zip3 constrs tags [0..]
      mm <- calcVecNumber constrs name
      cont1 mm $ \(m, lens) -> do
        let len = n + m
        debug $ "H: " ++ show len
        addTypeChangeStream name len
        forM_ constrsNtags $ \(CConstr (L s (Upp datacons)) cfts,tag,i) -> do
          let typeCons = CTAExpr (L s (Upp name))
              bool = CTAExpr (L s (Upp "Bool"))
              nat n = CTApp (noLocUpp "Nat") [CTAExpr (noLocDec n)]
              vec n | n == 1 = CTAExpr (noLocUpp "Bit")
                    | otherwise = CTApp (noLocUpp "Vec") [CTAExpr (noLocDec n)]
              isExpr = TCApp (noLocLow "equ")
                       [TCAExpr (noLocBin tag, vec n)
                       ,TCApp (noLocLow "sli")
                         [TCAExpr (noLocDec 0, nat 0)
                         ,TCAExpr (noLocDec (n-1), nat (n-1))
                         ,TCAExpr (noLocLow "_x0", typeCons)]
                         (vec n)]
                       bool
              getN (_,t) = getNumberFromType t
              catVars [v] = TCAExpr v
              catVars (v:vs) = TCApp (noLocLow "cat")
                               [TCAExpr v, catVars vs]
                               (vec (getN v + sum (map getN vs)))
              (k,_) = lens !! i
              r = m - k
              consExpr vars = case (vars,r) of
                ([],0) -> TCAExpr (noLocBin tag, vec n)
                ([],r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r), TCAExpr (noLocBin tag, vec n)] (vec len)
                ([x],0) -> TCApp (noLocLow "cat") [TCAExpr x,TCAExpr (noLocBin tag, vec n)] (vec len)
                ([x],r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r),TCApp (noLocLow "cat") [TCAExpr  x,TCAExpr (noLocBin tag, vec n)] (vec (k+n))] (vec len)
                (xs,0) -> TCApp (noLocLow "cat") [catVars xs,TCAExpr (noLocBin tag, vec n)] (vec len)
                (xs,r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r),TCApp (noLocLow "cat") [catVars xs,TCAExpr (noLocBin tag, vec n)] (vec (k+n))] (vec len)
          addTCFunc $ TCFunc
            (noLocLow ("__is__" ++ datacons))
            [(noLocLow "_x0", typeCons)]
            (TCNoGuards isExpr)
            bool
          mcfts_ <- mapM changeType cfts
          cont_ mcfts_ $ \cfts_ -> do
            let vars = zip (map (noLocLow . ("_x"++) . show) [0..]) cfts_
            addTCFunc $ TCFunc
              (L s (Low datacons))
              vars
              (TCNoGuards (consExpr vars))
              typeCons
            forM_ (zip cfts [0..]) $ \(cft,j) -> do
              isThere <- isThereTypeChange cft --getname?
              case isThere of
                True  -> mok
                False -> definePatternFunctions' (getNameFromType cft)
              mcft' <- changeType cft
              cont1 mcft' $ \cft' -> do
                debugs (j,m)
                let (_,lens') = lens !! i
                    ki = sum (take j lens') + n
                    k = lens' !! j
                    kf = ki + k - 1 
                    getExpr = TCApp (noLocLow "sli")
                              [TCAExpr (noLocDec ki, nat ki)
                              ,TCAExpr (noLocDec kf, nat kf)
                              ,TCAExpr (noLocLow "_x0", typeCons)]
                              (vec k)
                addTCFunc $ TCFunc
                  (noLocLow ("__get__" ++ datacons ++ "__" ++ show j))
                  [(noLocLow "_x0", typeCons)]
                  (TCNoGuards getExpr)
                  cft
                setDataUsed name 
                ret ()
            ret ()
          ret ()
        ret ()

getNameFromType :: CFType -> Name
getNameFromType cft = case cft of
  CTAExpr (L _ (Upp n)) -> n
  CTApp (L _ (Upp n)) _ -> n
  n -> error $ "getnamefromtype' " ++ show n

definePatternFunctionsNonRec :: (L Name, [CConstr], IsRec, Used)
                             -> TMM ()
definePatternFunctionsNonRec (L s name, constrs, _, used) = do
  case used of
    True -> mok
    False -> do
      let p = length constrs
          n = ceiling (logBase 2 (fromIntegral p))
          tags = map (toBin n) [0..(p-1)]
          constrsNtags = zip3 constrs tags [0..]
      mm <- calcVecNumber constrs name
      cont1 mm $ \(m, lens) -> do
        let len = n + m
        debug $ "H: " ++ show len
        addTypeChange name len
        forM_ constrsNtags $ \(CConstr (L s (Upp datacons)) cfts,tag,i) -> do
          let typeCons = CTAExpr (L s (Upp name))
              bool = CTAExpr (L s (Upp "Bool"))
              nat n = CTApp (noLocUpp "Nat") [CTAExpr (noLocDec n)]
              vec n | n == 1 = CTAExpr (noLocUpp "Bit")
                    | otherwise = CTApp (noLocUpp "Vec") [CTAExpr (noLocDec n)]
              isExpr = TCApp (noLocLow "equ")
                       [TCAExpr (noLocBin tag, vec n)
                       ,TCApp (noLocLow "sli")
                         [TCAExpr (noLocDec 0, nat 0)
                         ,TCAExpr (noLocDec (n-1), nat (n-1))
                         ,TCAExpr (noLocLow "_x0", typeCons)]
                         (vec n)]
                       bool
              getN (_,t) = getNumberFromType t
              catVars [v] = TCAExpr v
              catVars (v:vs) = TCApp (noLocLow "cat")
                               [TCAExpr v, catVars vs]
                               (vec (getN v + sum (map getN vs)))
              (k,_) = lens !! i
              r = m - k
              consExpr vars = case (vars,r) of
                ([],0) -> TCAExpr (noLocBin tag, vec n)
                ([],r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r), TCAExpr (noLocBin tag, vec n)] (vec len)
                ([x],0) -> TCApp (noLocLow "cat") [TCAExpr x,TCAExpr (noLocBin tag, vec n)] (vec len)
                ([x],r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r),TCApp (noLocLow "cat") [TCAExpr  x,TCAExpr (noLocBin tag, vec n)] (vec (k+n))] (vec len)
                (xs,0) -> TCApp (noLocLow "cat") [catVars xs,TCAExpr (noLocBin tag, vec n)] (vec len)
                (xs,r) -> TCApp (noLocLow "cat") [TCAExpr (noLocDec 0, vec r),TCApp (noLocLow "cat") [catVars xs,TCAExpr (noLocBin tag, vec n)] (vec (k+n))] (vec len)
          addTCFunc $ TCFunc
            (noLocLow ("__is__" ++ datacons))
            [(noLocLow "_x0", typeCons)]
            (TCNoGuards isExpr)
            bool
          mcfts_ <- mapM changeType cfts
          cont_ mcfts_ $ \cfts_ -> do
            let vars = zip (map (noLocLow . ("_x"++) . show) [0..]) cfts_
            addTCFunc $ TCFunc
              (L s (Upp datacons))
              vars
              (TCNoGuards (consExpr vars))
              typeCons
            forM_ (zip cfts [0..]) $ \(cft,j) -> do
              isThere <- isThereTypeChange cft --getname?
              case isThere of
                True  -> mok
                False -> definePatternFunctions' (getNameFromType cft)
              mcft' <- changeType cft
              cont1 mcft' $ \cft' -> do
                debugs (j,m)
                let (_,lens') = lens !! i
                    ki = sum (take j lens') + n
                    k = lens' !! j
                    kf = ki + k - 1 
                    getExpr = TCApp (noLocLow "sli")
                              [TCAExpr (noLocDec ki, nat ki)
                              ,TCAExpr (noLocDec kf, nat kf)
                              ,TCAExpr (noLocLow "_x0", typeCons)]
                              (vec k)
                addTCFunc $ TCFunc
                  (noLocLow ("__get__" ++ datacons ++ "__" ++ show j))
                  [(noLocLow "_x0", typeCons)]
                  (TCNoGuards getExpr)
                  cft
                setDataUsed name 
                ret ()
            ret ()
          ret ()
        ret ()

calcVecNumber :: [CConstr] -> Name -> TMM (Int, [(Int, [Int])])
calcVecNumber constrs name = do
  meach <- forM constrs $ \(CConstr _ cfts) -> do
    mnums <- forM cfts $ \cft -> do
      isThere <- isThereTypeChange cft --getname?
      case getNameFromType cft == name of
        True -> ret 0
        False -> do
          case isThere of
            True -> mok
            False -> definePatternFunctions' (getNameFromType cft)
          mcft' <- changeType cft
          cont1 mcft' $ \cft' -> do
            ret $ getNumberFromType cft'
    cont_ mnums $ \nums -> do
      ret (sum nums, nums)
  cont_ meach $ \each -> do
    ret (maximum (map fst each), each)
  
changeTypes :: TMM ()
changeTypes = do
  TCore fs <- getTCore
  mfs' <- forM fs $ \j@(TCFunc ltk vars tcgs ty) -> do
    debug $ "Changetypes name : " ++ show j
    mvars' <- forM vars $ \(vltk, vty) -> do
      mvty' <- changeType vty
      cont1 mvty' $ \vty' -> do
        debug "lllllllllll"
        ret (vltk, vty')
    mty' <- changeType ty
    mtcgs' <- changeTypeGs tcgs
    cont_ mvars' $ \vars' -> do
      debug "kkkkkkkkkk"
      cont1 mty' $ \ty' -> do
        debug "jjjjjjjjjjjjjj"
        cont1 mtcgs' $ \tcgs' -> do
          debug "ggggggggg"
          ret $ TCFunc ltk vars' tcgs' ty'
  cont_ mfs' $ \fs' -> do
    debug $ "aaaaaaa " ++ show (fs == fs')
    putTCore (TCore fs')
    ret ()

changeTypeGs :: TCGuards -> TMM TCGuards
changeTypeGs tcgs = case tcgs of
  TCNoGuards e -> do
    me' <- changeTypeExpr e
    cont1 me' $ \e' -> do
      ret $ TCNoGuards e'
  TCGuards ces -> do
    mces' <- forM ces $ \(c,e) -> do
      mc' <- changeTypeExpr c
      me' <- changeTypeExpr e
      cont2 mc' me' $ \c' e' -> do
        ret (c',e')
    cont_ mces' $ \ces' -> do
      ret $ TCGuards ces'

changeTypeExpr :: TCExpr -> TMM TCExpr
changeTypeExpr tcexpr = case tcexpr of
  TCApp name args ty -> do
   margs' <- mapM changeTypeExpr args
   mty' <- changeType ty
   cont_ margs' $ \args' -> do
     cont1 mty' $ \ty' -> do
       ret $ TCApp name args' ty'
  TCAExpr (name,ty) -> do
    mty' <- changeType ty
    cont1 mty' $ \ty' ->
      ret $ TCAExpr (name,ty')

toBin n = reverse . putZeros . dropWhile (=='0') . toBin'
  where
    putZeros s
      | length s < n = replicate (n - length s) '0' ++ s
      | otherwise    = s
    toBin' 0 = "0"
    toBin' n | n `mod` 2 == 1 = toBin' (n `div` 2) ++ "1"
             | n `mod` 2 == 0 = toBin' (n `div` 2) ++ "0"
