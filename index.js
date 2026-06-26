#!/usr/bin/env node
import inquirer from 'inquirer';
import chalk from 'chalk';
import {execSync} from 'child_process';

const GITHUB_USER='MyName-Yuuki';
const GITHUB_REPO='kantongkresek';
const BRANCH='main';
const BASE=`https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/scripts/`;

function run(name){
  console.log(chalk.cyan(`\nRunning ${name}...\n`));
  execSync(`bash <(curl -fsSL ${BASE}${name})`,{
    stdio:'inherit',
    shell:'/bin/bash'
  });
}

while(true){
 console.clear();
 console.log(chalk.green(`
=====================================
      KANTONGKRESEK INSTALLER
=====================================`));
 const {menu}=await inquirer.prompt([{
   type:'list',
   name:'menu',
   message:'Select Menu',
   choices:[
    {name:'1. Install Base',value:'1'},
    {name:'2. Configurations',value:'2'},
    {name:'3. Install Database',value:'3'},
    {name:'0. Exit',value:'0'}
   ]
 }]);
 try{
 switch(menu){
  case '1': run('install_base.sh'); break;
  case '2':
    run('configurations.sh');
    run('configurations_base_I.sh');
    run('configurations_base_II.sh');
    break;
  case '3': run('database.sh'); break;
  case '0': process.exit(0);
 }
 }catch(e){
   console.log(chalk.red("Script failed."));
   process.exit(1);
 }
 await inquirer.prompt([{type:'input',name:'c',message:'Press Enter...'}]);
}
